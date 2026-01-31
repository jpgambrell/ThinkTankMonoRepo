import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import {
  SecretsManagerClient,
  GetSecretValueCommand,
} from '@aws-sdk/client-secrets-manager';
import { ChatRequest, ChatResponse } from '../shared/types';
import { success, error, badRequest, internalError } from '../shared/response';

const secretsClient = new SecretsManagerClient({ region: process.env.REGION || 'us-east-1' });

// Cache the API key to avoid fetching it on every request
let cachedApiKey: string | null = null;

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

    // Generate conversation ID if not provided
    const conversationId = request.conversationId || generateConversationId();

    // Extract user ID from Cognito authorizer context
    const userId = event.requestContext.authorizer?.claims?.sub || 'anonymous';
    console.log('User ID:', userId);

    // Invoke OpenRouter model
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

function generateConversationId(): string {
  return `conv_${Date.now()}_${Math.random().toString(36).substring(7)}`;
}
