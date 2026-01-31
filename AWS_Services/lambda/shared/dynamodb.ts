import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import {
  DynamoDBDocumentClient,
  PutCommand,
  GetCommand,
  QueryCommand,
  DeleteCommand,
  UpdateCommand,
  BatchWriteCommand,
} from '@aws-sdk/lib-dynamodb';

// Initialize DynamoDB client
const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client, {
  marshallOptions: {
    removeUndefinedValues: true,
  },
});

const TABLE_NAME = process.env.CHAT_HISTORY_TABLE || 'thinktank-chat-history';

// Key generators for single-table design
export const userKey = (userId: string) => `USER#${userId}`;
export const convKey = (convId: string) => `CONV#${convId}`;
export const msgKey = (timestamp: string, msgId: string) => `MSG#${timestamp}#${msgId}`;

// Types for DynamoDB items
export interface ConversationItem {
  PK: string;
  SK: string;
  GSI1PK: string;
  GSI1SK: string;
  id: string;
  title: string;
  modelId: string;
  createdAt: string;
  updatedAt: string;
  messageCount: number;
  userId: string;
}

export interface MessageItem {
  PK: string;
  SK: string;
  id: string;
  role: 'user' | 'assistant';
  content: string;
  timestamp: string;
  modelId?: string;
  isError?: boolean;
  errorMessage?: string;
  userId: string;
  conversationId: string;
}

// DTOs for API responses
export interface ConversationDTO {
  id: string;
  title: string;
  modelId: string;
  createdAt: string;
  updatedAt: string;
  messageCount: number;
  messages?: MessageDTO[];
}

export interface MessageDTO {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  timestamp: string;
  modelId?: string;
  isError?: boolean;
  errorMessage?: string;
}

// Convert DynamoDB item to DTO
function conversationItemToDTO(item: ConversationItem): ConversationDTO {
  return {
    id: item.id,
    title: item.title,
    modelId: item.modelId,
    createdAt: item.createdAt,
    updatedAt: item.updatedAt,
    messageCount: item.messageCount,
  };
}

function messageItemToDTO(item: MessageItem): MessageDTO {
  return {
    id: item.id,
    role: item.role,
    content: item.content,
    timestamp: item.timestamp,
    modelId: item.modelId,
    isError: item.isError,
    errorMessage: item.errorMessage,
  };
}

// CRUD Operations

/**
 * Create a new conversation
 */
export async function createConversation(
  userId: string,
  conversation: {
    id: string;
    title: string;
    modelId: string;
  }
): Promise<ConversationDTO> {
  const now = new Date().toISOString();
  
  const item: ConversationItem = {
    PK: userKey(userId),
    SK: convKey(conversation.id),
    GSI1PK: userId,
    GSI1SK: now,
    id: conversation.id,
    title: conversation.title,
    modelId: conversation.modelId,
    createdAt: now,
    updatedAt: now,
    messageCount: 0,
    userId,
  };

  await docClient.send(new PutCommand({
    TableName: TABLE_NAME,
    Item: item,
  }));

  return conversationItemToDTO(item);
}

/**
 * List all conversations for a user, sorted by most recently updated
 */
export async function listConversations(
  userId: string,
  limit: number = 50
): Promise<ConversationDTO[]> {
  const result = await docClient.send(new QueryCommand({
    TableName: TABLE_NAME,
    IndexName: 'GSI1',
    KeyConditionExpression: 'GSI1PK = :userId',
    ExpressionAttributeValues: {
      ':userId': userId,
    },
    ScanIndexForward: false, // Sort by updatedAt descending (most recent first)
    Limit: limit,
  }));

  return (result.Items || []).map((item) => 
    conversationItemToDTO(item as ConversationItem)
  );
}

/**
 * Get a single conversation by ID
 */
export async function getConversation(
  userId: string,
  conversationId: string
): Promise<ConversationDTO | null> {
  const result = await docClient.send(new GetCommand({
    TableName: TABLE_NAME,
    Key: {
      PK: userKey(userId),
      SK: convKey(conversationId),
    },
  }));

  if (!result.Item) {
    return null;
  }

  return conversationItemToDTO(result.Item as ConversationItem);
}

/**
 * Get all messages for a conversation
 */
export async function getMessages(
  conversationId: string,
  limit: number = 100
): Promise<MessageDTO[]> {
  const result = await docClient.send(new QueryCommand({
    TableName: TABLE_NAME,
    KeyConditionExpression: 'PK = :pk AND begins_with(SK, :skPrefix)',
    ExpressionAttributeValues: {
      ':pk': convKey(conversationId),
      ':skPrefix': 'MSG#',
    },
    ScanIndexForward: true, // Sort by timestamp ascending (oldest first)
    Limit: limit,
  }));

  return (result.Items || []).map((item) => 
    messageItemToDTO(item as MessageItem)
  );
}

/**
 * Add a message to a conversation
 */
export async function addMessage(
  userId: string,
  conversationId: string,
  message: {
    id: string;
    role: 'user' | 'assistant';
    content: string;
    modelId?: string;
    isError?: boolean;
    errorMessage?: string;
  }
): Promise<MessageDTO> {
  const now = new Date().toISOString();
  
  const item: MessageItem = {
    PK: convKey(conversationId),
    SK: msgKey(now, message.id),
    id: message.id,
    role: message.role,
    content: message.content,
    timestamp: now,
    modelId: message.modelId,
    isError: message.isError,
    errorMessage: message.errorMessage,
    userId,
    conversationId,
  };

  await docClient.send(new PutCommand({
    TableName: TABLE_NAME,
    Item: item,
  }));

  return messageItemToDTO(item);
}

/**
 * Update conversation (title, modelId, updatedAt, messageCount)
 */
export async function updateConversation(
  userId: string,
  conversationId: string,
  updates: {
    title?: string;
    modelId?: string;
    incrementMessageCount?: number;
  }
): Promise<void> {
  const now = new Date().toISOString();
  
  const updateExpressions: string[] = ['#updatedAt = :updatedAt', 'GSI1SK = :updatedAt'];
  const expressionAttributeNames: Record<string, string> = {
    '#updatedAt': 'updatedAt',
  };
  const expressionAttributeValues: Record<string, any> = {
    ':updatedAt': now,
  };

  if (updates.title !== undefined) {
    updateExpressions.push('#title = :title');
    expressionAttributeNames['#title'] = 'title';
    expressionAttributeValues[':title'] = updates.title;
  }

  if (updates.modelId !== undefined) {
    updateExpressions.push('#modelId = :modelId');
    expressionAttributeNames['#modelId'] = 'modelId';
    expressionAttributeValues[':modelId'] = updates.modelId;
  }

  if (updates.incrementMessageCount !== undefined) {
    updateExpressions.push('#messageCount = #messageCount + :increment');
    expressionAttributeNames['#messageCount'] = 'messageCount';
    expressionAttributeValues[':increment'] = updates.incrementMessageCount;
  }

  await docClient.send(new UpdateCommand({
    TableName: TABLE_NAME,
    Key: {
      PK: userKey(userId),
      SK: convKey(conversationId),
    },
    UpdateExpression: 'SET ' + updateExpressions.join(', '),
    ExpressionAttributeNames: expressionAttributeNames,
    ExpressionAttributeValues: expressionAttributeValues,
  }));
}

/**
 * Delete a conversation and all its messages
 */
export async function deleteConversation(
  userId: string,
  conversationId: string
): Promise<void> {
  // First, get all messages for the conversation
  const messagesResult = await docClient.send(new QueryCommand({
    TableName: TABLE_NAME,
    KeyConditionExpression: 'PK = :pk AND begins_with(SK, :skPrefix)',
    ExpressionAttributeValues: {
      ':pk': convKey(conversationId),
      ':skPrefix': 'MSG#',
    },
    ProjectionExpression: 'PK, SK',
  }));

  // Delete messages in batches of 25 (DynamoDB limit)
  const messageItems = messagesResult.Items || [];
  for (let i = 0; i < messageItems.length; i += 25) {
    const batch = messageItems.slice(i, i + 25);
    await docClient.send(new BatchWriteCommand({
      RequestItems: {
        [TABLE_NAME]: batch.map((item) => ({
          DeleteRequest: {
            Key: { PK: item.PK, SK: item.SK },
          },
        })),
      },
    }));
  }

  // Delete the conversation itself
  await docClient.send(new DeleteCommand({
    TableName: TABLE_NAME,
    Key: {
      PK: userKey(userId),
      SK: convKey(conversationId),
    },
  }));
}

/**
 * Check if a conversation exists and belongs to the user
 */
export async function conversationExists(
  userId: string,
  conversationId: string
): Promise<boolean> {
  const result = await docClient.send(new GetCommand({
    TableName: TABLE_NAME,
    Key: {
      PK: userKey(userId),
      SK: convKey(conversationId),
    },
    ProjectionExpression: 'PK',
  }));

  return !!result.Item;
}
