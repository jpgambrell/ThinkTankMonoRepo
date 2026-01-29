import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { ModelsResponse, ModelInfo } from '../shared/types';
import { success, internalError } from '../shared/response';

// Static list of available Bedrock models
// In production, this could query Bedrock ListFoundationModels API
const AVAILABLE_MODELS: ModelInfo[] = [
  {
    modelId: 'anthropic.claude-3-5-sonnet',
    displayName: 'Claude 3.5 Sonnet',
    provider: 'Anthropic',
    maxTokens: 200000,
    streaming: true,
  },
  {
    modelId: 'anthropic.claude-3-opus',
    displayName: 'Claude 3 Opus',
    provider: 'Anthropic',
    maxTokens: 200000,
    streaming: true,
  },
  {
    modelId: 'anthropic.claude-3-haiku',
    displayName: 'Claude 3 Haiku',
    provider: 'Anthropic',
    maxTokens: 200000,
    streaming: true,
  },
  {
    modelId: 'amazon.titan-text-express',
    displayName: 'Titan Text Express',
    provider: 'Amazon',
    maxTokens: 8000,
    streaming: true,
  },
  {
    modelId: 'meta.llama3-70b',
    displayName: 'Llama 3 70B',
    provider: 'Meta',
    maxTokens: 8000,
    streaming: true,
  },
  {
    modelId: 'mistral.mixtral-8x7b',
    displayName: 'Mixtral 8x7B',
    provider: 'Mistral',
    maxTokens: 32000,
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
    // 2. Query Bedrock API for dynamic model availability
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
