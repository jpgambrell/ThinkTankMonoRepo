import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import {
  SecretsManagerClient,
  GetSecretValueCommand,
} from '@aws-sdk/client-secrets-manager';
import { ChatRequest, ChatResponse } from '../shared/types';
import { success, badRequest, internalError } from '../shared/response';

// Lambda Response Streaming types - these are provided by the Lambda runtime globally
declare global {
  const awslambda: {
    streamifyResponse: (
      handler: (event: APIGatewayProxyEvent, responseStream: ResponseStream) => Promise<void>
    ) => (event: APIGatewayProxyEvent) => Promise<void>;
    HttpResponseStream: {
      from: (responseStream: ResponseStream, metadata: ResponseMetadata) => ResponseStream;
    };
  };
}

interface ResponseStream {
  write(data: string): void;
  end(): void;
}

interface ResponseMetadata {
  statusCode: number;
  headers: Record<string, string>;
}

const secretsClient = new SecretsManagerClient({ region: process.env.REGION || 'us-east-1' });

// Cache the API key to avoid fetching it on every request
let cachedApiKey: string | null = null;
let cachedJwks: { keys: JWK[] } | null = null;

interface JWK {
  kid: string;
  kty: string;
  n: string;
  e: string;
  alg: string;
  use: string;
}

async function getApiKey(): Promise<string> {
  if (cachedApiKey) return cachedApiKey;

  const response = await secretsClient.send(
    new GetSecretValueCommand({
      SecretId: process.env.OPENROUTER_SECRET_ARN,
    })
  );

  const secret = JSON.parse(response.SecretString!);
  cachedApiKey = secret.OPENROUTER_API_KEY;
  return cachedApiKey!;
}

// Validate Cognito JWT token (simplified validation for Function URL)
async function validateToken(authHeader: string | undefined): Promise<{ sub: string } | null> {
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return null;
  }

  const token = authHeader.substring(7);
  
  try {
    // Decode JWT without verification for user ID extraction
    // In production, you should fully verify the token signature
    const parts = token.split('.');
    if (parts.length !== 3) return null;
    
    const payload = JSON.parse(Buffer.from(parts[1], 'base64url').toString());
    
    // Basic validation
    const now = Math.floor(Date.now() / 1000);
    if (payload.exp && payload.exp < now) {
      console.log('Token expired');
      return null;
    }
    
    // Verify issuer matches our user pool
    const expectedIssuer = `https://cognito-idp.${process.env.REGION}.amazonaws.com/${process.env.COGNITO_USER_POOL_ID}`;
    if (payload.iss !== expectedIssuer) {
      console.log('Invalid issuer:', payload.iss, 'expected:', expectedIssuer);
      return null;
    }
    
    return { sub: payload.sub };
  } catch (err) {
    console.error('Token validation error:', err);
    return null;
  }
}

// Standard API Gateway handler (non-streaming)
export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
  try {
    console.log('Chat request received:', JSON.stringify(event, null, 2));

    // Parse request body
    if (!event.body) {
      return badRequest('Request body is required');
    }

    const request: ChatRequest = JSON.parse(event.body);

    // Validate request
    if (!request.modelId || !request.messages || request.messages.length === 0) {
      return badRequest('modelId and messages are required');
    }

    // Check if streaming is requested - if so, this shouldn't go through API Gateway
    if (request.stream) {
      return badRequest('Streaming requests should use the streaming endpoint');
    }

    // Generate conversation ID if not provided
    const conversationId = request.conversationId || generateConversationId();

    // Extract user ID from Cognito authorizer context
    const userId = event.requestContext.authorizer?.claims?.sub || 'anonymous';
    console.log('User ID:', userId);

    // Invoke OpenRouter model (non-streaming)
    const response = await invokeOpenRouter(request.modelId, request.messages);

    // Build response
    const chatResponse: ChatResponse = {
      conversationId,
      message: {
        role: 'assistant',
        content: response.content,
      },
      usage: response.usage,
    };

    return success(chatResponse);
  } catch (err) {
    console.error('Error processing chat request:', err);
    const errorMessage = err instanceof Error ? err.message : 'Unknown error occurred';
    return internalError(errorMessage);
  }
};

// Streaming handler for Lambda Function URL
export const streamHandler = awslambda.streamifyResponse(
  async (event: APIGatewayProxyEvent, responseStream: ResponseStream): Promise<void> => {
    // Set SSE content type
    const metadata: ResponseMetadata = {
      statusCode: 200,
      headers: {
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache',
        'Connection': 'keep-alive',
      },
    };

    responseStream = awslambda.HttpResponseStream.from(responseStream, metadata);

    try {
      console.log('Streaming chat request received');

      // Validate token for Function URL (no built-in Cognito auth)
      const authHeader = event.headers?.['authorization'] || event.headers?.['Authorization'];
      const user = await validateToken(authHeader);
      
      if (!user) {
        responseStream.write('data: {"error":{"message":"Unauthorized"}}\n\n');
        responseStream.end();
        return;
      }

      console.log('User ID:', user.sub);

      // Parse request body
      if (!event.body) {
        responseStream.write('data: {"error":{"message":"Request body is required"}}\n\n');
        responseStream.end();
        return;
      }

      const request: ChatRequest = JSON.parse(event.body);

      // Validate request
      if (!request.modelId || !request.messages || request.messages.length === 0) {
        responseStream.write('data: {"error":{"message":"modelId and messages are required"}}\n\n');
        responseStream.end();
        return;
      }

      // Stream from OpenRouter
      await invokeOpenRouterStreaming(request.modelId, request.messages, responseStream);

      responseStream.write('data: [DONE]\n\n');
      responseStream.end();
    } catch (err) {
      console.error('Error in streaming handler:', err);
      const errorMessage = err instanceof Error ? err.message : 'Unknown error';
      try {
        responseStream.write(`data: {"error":{"message":"${errorMessage.replace(/"/g, '\\"')}"}}\n\n`);
      } catch {
        // Stream may already be closed
      }
      responseStream.end();
    }
  }
);

async function invokeOpenRouter(
  modelId: string,
  messages: ChatRequest['messages']
): Promise<{ content: string; usage?: { inputTokens: number; outputTokens: number } }> {
  const apiKey = await getApiKey();

  console.log('Calling OpenRouter with model:', modelId);

  const response = await fetch('https://openrouter.ai/api/v1/chat/completions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
      'HTTP-Referer': 'https://thinktank.app',
      'X-Title': 'ThinkTank',
    },
    body: JSON.stringify({
      model: modelId,
      messages: messages.map((m) => ({ role: m.role, content: m.content })),
      max_tokens: 4096,
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    console.error('OpenRouter API error:', response.status, errorText);
    throw new Error(`OpenRouter API error: ${response.status} - ${errorText}`);
  }

  interface OpenRouterResponse {
    choices?: Array<{
      message?: {
        content?: string;
      };
    }>;
    usage?: {
      prompt_tokens: number;
      completion_tokens: number;
    };
  }

  const data = (await response.json()) as OpenRouterResponse;

  console.log('OpenRouter response:', JSON.stringify(data, null, 2));

  // Handle the response - OpenRouter uses OpenAI-compatible format
  const content = data.choices?.[0]?.message?.content;
  if (!content) {
    throw new Error('No content in OpenRouter response');
  }

  return {
    content,
    usage: data.usage
      ? {
          inputTokens: data.usage.prompt_tokens,
          outputTokens: data.usage.completion_tokens,
        }
      : undefined,
  };
}

async function invokeOpenRouterStreaming(
  modelId: string,
  messages: ChatRequest['messages'],
  responseStream: ResponseStream
): Promise<void> {
  const apiKey = await getApiKey();

  console.log('Calling OpenRouter with streaming, model:', modelId);

  const response = await fetch('https://openrouter.ai/api/v1/chat/completions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
      'HTTP-Referer': 'https://thinktank.app',
      'X-Title': 'ThinkTank',
    },
    body: JSON.stringify({
      model: modelId,
      messages: messages.map((m) => ({ role: m.role, content: m.content })),
      max_tokens: 4096,
      stream: true, // Enable streaming from OpenRouter
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    console.error('OpenRouter API error:', response.status, errorText);
    throw new Error(`OpenRouter API error: ${response.status} - ${errorText}`);
  }

  if (!response.body) {
    throw new Error('No response body from OpenRouter');
  }

  // Stream the response directly to the client
  const reader = response.body.getReader();
  const decoder = new TextDecoder();

  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;

      const chunk = decoder.decode(value, { stream: true });
      
      // Forward the SSE data directly - OpenRouter already sends in SSE format
      responseStream.write(chunk);
    }
  } finally {
    reader.releaseLock();
  }
}

function generateConversationId(): string {
  return `conv_${Date.now()}_${Math.random().toString(36).substring(7)}`;
}
