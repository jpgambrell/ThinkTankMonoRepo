import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { ModelsResponse, ModelInfo } from '../shared/types';
import { success, internalError } from '../shared/response';

// Available models via OpenRouter
// See https://openrouter.ai/models for full list and pricing
const AVAILABLE_MODELS: ModelInfo[] = [
  // Anthropic Claude Family
  {
    modelId: 'anthropic/claude-sonnet-4',
    displayName: 'Claude Sonnet 4',
    provider: 'Anthropic',
    maxTokens: 200000,
    streaming: true,
  },
  {
    modelId: 'anthropic/claude-opus-4',
    displayName: 'Claude Opus 4',
    provider: 'Anthropic',
    maxTokens: 200000,
    streaming: true,
  },
  {
    modelId: 'anthropic/claude-3.5-haiku',
    displayName: 'Claude 3.5 Haiku',
    provider: 'Anthropic',
    maxTokens: 200000,
    streaming: true,
  },
  // DeepSeek
  {
    modelId: 'deepseek/deepseek-r1',
    displayName: 'DeepSeek-R1',
    provider: 'DeepSeek',
    maxTokens: 128000,
    streaming: true,
  },
  // OpenAI
  {
    modelId: 'openai/gpt-4o',
    displayName: 'GPT-4o',
    provider: 'OpenAI',
    maxTokens: 128000,
    streaming: true,
  },
  {
    modelId: 'openai/gpt-4o-mini',
    displayName: 'GPT-4o Mini',
    provider: 'OpenAI',
    maxTokens: 128000,
    streaming: true,
  },
  // Meta Llama
  {
    modelId: 'meta-llama/llama-3.3-70b-instruct',
    displayName: 'Llama 3.3 70B',
    provider: 'Meta',
    maxTokens: 131072,
    streaming: true,
  },
  // Google
  {
    modelId: 'google/gemini-2.0-flash-001',
    displayName: 'Gemini 2.0 Flash',
    provider: 'Google',
    maxTokens: 1048576,
    streaming: true,
  },
];

export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
  try {
    console.log('Models request received:', JSON.stringify(event, null, 2));

    // Extract user ID from Cognito authorizer context
    const userId = event.requestContext.authorizer?.claims?.sub || 'anonymous';
    console.log('User ID:', userId);

    // In a real implementation, you might:
    // 1. Filter models based on user permissions/subscription
    // 2. Query OpenRouter API for dynamic model availability
    // 3. Return model pricing information

    const response: ModelsResponse = {
      models: AVAILABLE_MODELS,
    };

    return success(response);
  } catch (err) {
    console.error('Error retrieving models:', err);
    const errorMessage = err instanceof Error ? err.message : 'Unknown error occurred';
    return internalError(errorMessage);
  }
};
