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

// Conversation and Message DTOs for API responses

export interface MessageDTO {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  timestamp: string;
  modelId?: string;
  isError?: boolean;
  errorMessage?: string;
}

export interface ConversationDTO {
  id: string;
  title: string;
  modelId: string;
  createdAt: string;
  updatedAt: string;
  messageCount: number;
  messages?: MessageDTO[];
}

export interface ConversationsListResponse {
  conversations: ConversationDTO[];
}

export interface ConversationResponse {
  conversation: ConversationDTO;
}

export interface MessageResponse {
  message: MessageDTO;
}

export interface CreateConversationRequest {
  title?: string;
  modelId: string;
}

export interface UpdateConversationRequest {
  title?: string;
  modelId?: string;
}

export interface AddMessageRequest {
  role: 'user' | 'assistant';
  content: string;
  modelId?: string;
  isError?: boolean;
  errorMessage?: string;
}
