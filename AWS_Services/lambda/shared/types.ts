// Shared types for Lambda functions

export interface Message {
  role: 'user' | 'assistant';
  content: string;
}

export interface ChatRequest {
  conversationId?: string;
  modelId: string;
  messages: Message[];
  stream?: boolean;
}

export interface ChatResponse {
  conversationId: string;
  message: Message;
  usage?: {
    inputTokens: number;
    outputTokens: number;
  };
}

export interface ModelInfo {
  modelId: string;
  displayName: string;
  provider: string;
  maxTokens: number;
  streaming: boolean;
}

export interface ModelsResponse {
  models: ModelInfo[];
}

export interface ErrorResponse {
  error: string;
  message: string;
  statusCode: number;
}
