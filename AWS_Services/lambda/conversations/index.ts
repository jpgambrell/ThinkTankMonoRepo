import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import {
  createConversation,
  listConversations,
  getConversation,
  getMessages,
  updateConversation,
  deleteConversation,
  addMessage,
  ConversationDTO,
  MessageDTO,
} from '../shared/dynamodb';
import { createResponse, createErrorResponse } from '../shared/response';

/**
 * Extract user ID from Cognito authorizer claims
 */
function getUserId(event: APIGatewayProxyEvent): string | null {
  const claims = event.requestContext.authorizer?.claims;
  return claims?.sub || null;
}

/**
 * Generate a unique ID for conversations and messages
 */
function generateId(): string {
  return `${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
}

/**
 * Main handler for conversation operations
 */
export async function handler(event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> {
  console.log('Received event:', JSON.stringify(event, null, 2));

  const userId = getUserId(event);
  if (!userId) {
    return createErrorResponse(401, 'Unauthorized', 'User ID not found in token');
  }

  const method = event.httpMethod;
  const path = event.path;
  const pathParams = event.pathParameters;

  try {
    // Route based on method and path
    // GET /conversations - List all conversations
    if (method === 'GET' && path === '/conversations') {
      return await handleListConversations(userId);
    }

    // POST /conversations - Create new conversation
    if (method === 'POST' && path === '/conversations') {
      return await handleCreateConversation(userId, event.body);
    }

    // GET /conversations/{conversationId} - Get conversation with messages
    if (method === 'GET' && pathParams?.conversationId && !path.includes('/messages')) {
      return await handleGetConversation(userId, pathParams.conversationId);
    }

    // PUT /conversations/{conversationId} - Update conversation
    if (method === 'PUT' && pathParams?.conversationId) {
      return await handleUpdateConversation(userId, pathParams.conversationId, event.body);
    }

    // DELETE /conversations/{conversationId} - Delete conversation
    if (method === 'DELETE' && pathParams?.conversationId) {
      return await handleDeleteConversation(userId, pathParams.conversationId);
    }

    // POST /conversations/{conversationId}/messages - Add message
    if (method === 'POST' && pathParams?.conversationId && path.includes('/messages')) {
      return await handleAddMessage(userId, pathParams.conversationId, event.body);
    }

    return createErrorResponse(404, 'Not Found', `Route not found: ${method} ${path}`);
  } catch (error) {
    console.error('Error handling request:', error);
    return createErrorResponse(
      500,
      'Internal Server Error',
      error instanceof Error ? error.message : 'Unknown error'
    );
  }
}

/**
 * List all conversations for the user
 */
async function handleListConversations(userId: string): Promise<APIGatewayProxyResult> {
  const conversations = await listConversations(userId);
  return createResponse(200, { conversations });
}

/**
 * Create a new conversation
 */
async function handleCreateConversation(
  userId: string,
  body: string | null
): Promise<APIGatewayProxyResult> {
  if (!body) {
    return createErrorResponse(400, 'Bad Request', 'Request body is required');
  }

  const data = JSON.parse(body);
  const { title, modelId } = data;

  if (!modelId) {
    return createErrorResponse(400, 'Bad Request', 'modelId is required');
  }

  const conversation = await createConversation(userId, {
    id: generateId(),
    title: title || 'New Chat',
    modelId,
  });

  return createResponse(201, { conversation });
}

/**
 * Get a conversation with its messages
 */
async function handleGetConversation(
  userId: string,
  conversationId: string
): Promise<APIGatewayProxyResult> {
  const conversation = await getConversation(userId, conversationId);
  
  if (!conversation) {
    return createErrorResponse(404, 'Not Found', 'Conversation not found');
  }

  const messages = await getMessages(conversationId);
  
  return createResponse(200, {
    conversation: {
      ...conversation,
      messages,
    },
  });
}

/**
 * Update a conversation (title, modelId)
 */
async function handleUpdateConversation(
  userId: string,
  conversationId: string,
  body: string | null
): Promise<APIGatewayProxyResult> {
  if (!body) {
    return createErrorResponse(400, 'Bad Request', 'Request body is required');
  }

  // Check if conversation exists
  const existing = await getConversation(userId, conversationId);
  if (!existing) {
    return createErrorResponse(404, 'Not Found', 'Conversation not found');
  }

  const data = JSON.parse(body);
  const { title, modelId } = data;

  await updateConversation(userId, conversationId, {
    title,
    modelId,
  });

  // Get updated conversation
  const updated = await getConversation(userId, conversationId);
  return createResponse(200, { conversation: updated });
}

/**
 * Delete a conversation and all its messages
 */
async function handleDeleteConversation(
  userId: string,
  conversationId: string
): Promise<APIGatewayProxyResult> {
  // Check if conversation exists
  const existing = await getConversation(userId, conversationId);
  if (!existing) {
    return createErrorResponse(404, 'Not Found', 'Conversation not found');
  }

  await deleteConversation(userId, conversationId);
  return createResponse(200, { message: 'Conversation deleted successfully' });
}

/**
 * Add a message to a conversation
 */
async function handleAddMessage(
  userId: string,
  conversationId: string,
  body: string | null
): Promise<APIGatewayProxyResult> {
  if (!body) {
    return createErrorResponse(400, 'Bad Request', 'Request body is required');
  }

  // Check if conversation exists
  const existing = await getConversation(userId, conversationId);
  if (!existing) {
    return createErrorResponse(404, 'Not Found', 'Conversation not found');
  }

  const data = JSON.parse(body);
  const { role, content, modelId, isError, errorMessage } = data;

  if (!role || !content) {
    return createErrorResponse(400, 'Bad Request', 'role and content are required');
  }

  if (role !== 'user' && role !== 'assistant') {
    return createErrorResponse(400, 'Bad Request', 'role must be "user" or "assistant"');
  }

  const message = await addMessage(userId, conversationId, {
    id: generateId(),
    role,
    content,
    modelId,
    isError,
    errorMessage,
  });

  // Update conversation message count and timestamp
  await updateConversation(userId, conversationId, {
    incrementMessageCount: 1,
  });

  return createResponse(201, { message });
}
