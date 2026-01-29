import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import {
  BedrockRuntimeClient,
  InvokeModelCommand,
  InvokeModelCommandInput,
} from '@aws-sdk/client-bedrock-runtime';
import { ChatRequest, ChatResponse } from '../shared/types';
import { success, error, badRequest, internalError } from '../shared/response';

const bedrockClient = new BedrockRuntimeClient({ region: process.env.REGION || 'us-east-1' });

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

    // Invoke Bedrock model
    const response = await invokeBedrockModel(request.modelId, request.messages);

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

async function invokeBedrockModel(
  modelId: string,
  messages: ChatRequest['messages']
): Promise<{ content: string; usage?: any }> {
  // Map short model IDs to full Bedrock model IDs
  // Note: Some models require cross-region inference profiles (prefixed with 'us.')
  const modelArnMap: Record<string, string> = {
    // Claude 4.5 Family (cross-region inference profiles)
    'anthropic.claude-opus-4-5': 'us.anthropic.claude-opus-4-5-20251101-v1:0',
    'anthropic.claude-sonnet-4-5': 'us.anthropic.claude-sonnet-4-5-20250929-v1:0',
    'anthropic.claude-haiku-4-5': 'us.anthropic.claude-haiku-4-5-20251001-v1:0',
    // DeepSeek (cross-region inference profile required)
    'deepseek.r1': 'us.deepseek.r1-v1:0',
  };

  const fullModelId = modelArnMap[modelId] || modelId;
  console.log('Using model:', fullModelId);

  // Prepare request based on model provider
  // Note: Check includes() to handle cross-region inference profiles with 'us.' prefix
  if (fullModelId.includes('anthropic.claude')) {
    return await invokeClaude(fullModelId, messages);
  } else if (fullModelId.includes('deepseek.')) {
    return await invokeDeepSeek(fullModelId, messages);
  } else if (fullModelId.includes('amazon.titan')) {
    return await invokeTitan(fullModelId, messages);
  } else if (fullModelId.includes('meta.llama')) {
    return await invokeLlama(fullModelId, messages);
  } else if (fullModelId.includes('mistral.')) {
    return await invokeMistral(fullModelId, messages);
  } else {
    throw new Error(`Unsupported model: ${modelId}`);
  }
}

async function invokeClaude(
  modelId: string,
  messages: ChatRequest['messages']
): Promise<{ content: string; usage?: any }> {
  const payload = {
    anthropic_version: 'bedrock-2023-05-31',
    max_tokens: 4096,
    messages: messages.map((msg) => ({
      role: msg.role,
      content: msg.content,
    })),
  };

  const command = new InvokeModelCommand({
    modelId,
    contentType: 'application/json',
    accept: 'application/json',
    body: JSON.stringify(payload),
  });

  const response = await bedrockClient.send(command);
  const responseBody = JSON.parse(new TextDecoder().decode(response.body));

  return {
    content: responseBody.content[0].text,
    usage: {
      inputTokens: responseBody.usage.input_tokens,
      outputTokens: responseBody.usage.output_tokens,
    },
  };
}

async function invokeTitan(
  modelId: string,
  messages: ChatRequest['messages']
): Promise<{ content: string; usage?: any }> {
  // Combine messages into a single prompt for Titan
  const prompt = messages.map((msg) => `${msg.role}: ${msg.content}`).join('\n\n');

  const payload = {
    inputText: prompt,
    textGenerationConfig: {
      maxTokenCount: 4096,
      temperature: 0.7,
      topP: 0.9,
    },
  };

  const command = new InvokeModelCommand({
    modelId,
    contentType: 'application/json',
    accept: 'application/json',
    body: JSON.stringify(payload),
  });

  const response = await bedrockClient.send(command);
  const responseBody = JSON.parse(new TextDecoder().decode(response.body));

  return {
    content: responseBody.results[0].outputText,
    usage: {
      inputTokens: responseBody.inputTextTokenCount,
      outputTokens: responseBody.results[0].tokenCount,
    },
  };
}

async function invokeLlama(
  modelId: string,
  messages: ChatRequest['messages']
): Promise<{ content: string; usage?: any }> {
  // Format messages for Llama
  const prompt = messages.map((msg) => `<|${msg.role}|>\n${msg.content}`).join('\n\n');

  const payload = {
    prompt,
    max_gen_len: 2048,
    temperature: 0.7,
    top_p: 0.9,
  };

  const command = new InvokeModelCommand({
    modelId,
    contentType: 'application/json',
    accept: 'application/json',
    body: JSON.stringify(payload),
  });

  const response = await bedrockClient.send(command);
  const responseBody = JSON.parse(new TextDecoder().decode(response.body));

  return {
    content: responseBody.generation,
    usage: {
      inputTokens: responseBody.prompt_token_count,
      outputTokens: responseBody.generation_token_count,
    },
  };
}

async function invokeMistral(
  modelId: string,
  messages: ChatRequest['messages']
): Promise<{ content: string; usage?: any }> {
  const prompt = `<s>${messages.map((msg) => `[INST] ${msg.content} [/INST]`).join(' ')}`;

  const payload = {
    prompt,
    max_tokens: 2048,
    temperature: 0.7,
    top_p: 0.9,
  };

  const command = new InvokeModelCommand({
    modelId,
    contentType: 'application/json',
    accept: 'application/json',
    body: JSON.stringify(payload),
  });

  const response = await bedrockClient.send(command);
  const responseBody = JSON.parse(new TextDecoder().decode(response.body));

  return {
    content: responseBody.outputs[0].text,
  };
}

async function invokeDeepSeek(
  modelId: string,
  messages: ChatRequest['messages']
): Promise<{ content: string; usage?: any }> {
  // DeepSeek-R1 uses a similar format to other chat models
  const payload = {
    messages: messages.map((msg) => ({
      role: msg.role,
      content: msg.content,
    })),
    max_tokens: 4096,
    temperature: 0.7,
    top_p: 0.9,
  };

  const command = new InvokeModelCommand({
    modelId,
    contentType: 'application/json',
    accept: 'application/json',
    body: JSON.stringify(payload),
  });

  const response = await bedrockClient.send(command);
  const responseBody = JSON.parse(new TextDecoder().decode(response.body));

  // DeepSeek returns response in choices[0].message.content format
  return {
    content: responseBody.choices?.[0]?.message?.content || responseBody.content || responseBody.output,
    usage: responseBody.usage ? {
      inputTokens: responseBody.usage.prompt_tokens,
      outputTokens: responseBody.usage.completion_tokens,
    } : undefined,
  };
}

function generateConversationId(): string {
  return `conv_${Date.now()}_${Math.random().toString(36).substring(7)}`;
}
