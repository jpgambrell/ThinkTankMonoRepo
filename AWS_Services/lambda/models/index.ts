import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { ModelsResponse, ModelInfo } from '../shared/types';
import { success, internalError } from '../shared/response';

// Available models via OpenRouter
// See https://openrouter.ai/models for full list and pricing
// Synced with appModelList.md on 2026-02-05
const AVAILABLE_MODELS: ModelInfo[] = [
  // Anthropic Claude Family
  {
    modelId: 'anthropic/claude-opus-4.6',
    displayName: 'Claude Opus 4.6',
    provider: 'Anthropic',
    maxTokens: 1000000,
    streaming: true,
  },
  {
    modelId: 'anthropic/claude-opus-4.5',
    displayName: 'Claude Opus 4.5',
    provider: 'Anthropic',
    maxTokens: 200000,
    streaming: true,
  },
  {
    modelId: 'anthropic/claude-sonnet-4.5',
    displayName: 'Claude Sonnet 4.5',
    provider: 'Anthropic',
    maxTokens: 200000,
    streaming: true,
  },
  // DeepSeek
  {
    modelId: 'deepseek/deepseek-v3.2-speciale',
    displayName: 'DeepSeek V3.2 Speciale',
    provider: 'DeepSeek',
    maxTokens: 163840,
    streaming: true,
  },
  {
    modelId: 'deepseek/deepseek-v3.2',
    displayName: 'DeepSeek V3.2',
    provider: 'DeepSeek',
    maxTokens: 163840,
    streaming: true,
  },
  {
    modelId: 'deepseek/deepseek-v3.2-exp',
    displayName: 'DeepSeek V3.2 Exp',
    provider: 'DeepSeek',
    maxTokens: 163840,
    streaming: true,
  },
  // Google Gemini Family
  {
    modelId: 'google/gemini-3-flash-preview',
    displayName: 'Gemini 3 Flash Preview',
    provider: 'Google',
    maxTokens: 1048576,
    streaming: true,
  },
  {
    modelId: 'google/gemini-3-pro-preview',
    displayName: 'Gemini 3 Pro Preview',
    provider: 'Google',
    maxTokens: 1048576,
    streaming: true,
  },
  {
    modelId: 'google/gemini-2.5-flash-lite',
    displayName: 'Gemini 2.5 Flash Lite',
    provider: 'Google',
    maxTokens: 1048576,
    streaming: true,
  },
  {
    modelId: 'google/gemini-2.5-flash',
    displayName: 'Gemini 2.5 Flash',
    provider: 'Google',
    maxTokens: 1048576,
    streaming: true,
  },
  {
    modelId: 'google/gemini-2.5-pro',
    displayName: 'Gemini 2.5 Pro',
    provider: 'Google',
    maxTokens: 1048576,
    streaming: true,
  },
  // OpenAI GPT Family
  {
    modelId: 'openai/gpt-5.2-codex',
    displayName: 'GPT-5.2 Codex',
    provider: 'OpenAI',
    maxTokens: 400000,
    streaming: true,
  },
  {
    modelId: 'openai/gpt-5.2-chat',
    displayName: 'GPT-5.2 Chat',
    provider: 'OpenAI',
    maxTokens: 128000,
    streaming: true,
  },
  {
    modelId: 'openai/gpt-5.2-pro',
    displayName: 'GPT-5.2 Pro',
    provider: 'OpenAI',
    maxTokens: 400000,
    streaming: true,
  },
  {
    modelId: 'openai/gpt-5.2',
    displayName: 'GPT-5.2',
    provider: 'OpenAI',
    maxTokens: 400000,
    streaming: true,
  },
  {
    modelId: 'openai/gpt-4o-mini',
    displayName: 'GPT-4o Mini',
    provider: 'OpenAI',
    maxTokens: 128000,
    streaming: true,
  },
  // Meta Llama Family
  {
    modelId: 'meta-llama/llama-guard-4-12b',
    displayName: 'Llama Guard 4 12B',
    provider: 'Meta',
    maxTokens: 131072,
    streaming: true,
  },
  {
    modelId: 'meta-llama/llama-4-maverick',
    displayName: 'Llama 4 Maverick',
    provider: 'Meta',
    maxTokens: 1048576,
    streaming: true,
  },
  {
    modelId: 'meta-llama/llama-4-scout',
    displayName: 'Llama 4 Scout',
    provider: 'Meta',
    maxTokens: 524288,
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
