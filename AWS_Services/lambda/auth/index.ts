import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import {
  CognitoIdentityProviderClient,
  AdminUpdateUserAttributesCommand,
  AdminSetUserPasswordCommand,
} from '@aws-sdk/client-cognito-identity-provider';
import { createResponse, createErrorResponse } from '../shared/response';

const cognitoClient = new CognitoIdentityProviderClient({
  region: process.env.REGION || 'us-east-1',
});

/**
 * Extract user ID from Cognito authorizer claims
 */
function getUserId(event: APIGatewayProxyEvent): string | null {
  const claims = event.requestContext.authorizer?.claims;
  console.log('Authorizer claims:', JSON.stringify(claims, null, 2));
  return claims?.sub || null;
}

/**
 * Get the username (email) from Cognito claims
 * Cognito authorizer flattens claims, so we check multiple possible fields
 */
function getUsername(event: APIGatewayProxyEvent): string | null {
  const claims = event.requestContext.authorizer?.claims;
  if (!claims) {
    console.log('No claims found in authorizer');
    return null;
  }
  
  // Try different claim fields where username/email might be
  const username = claims.email || 
                   claims['cognito:username'] || 
                   claims.username ||
                   claims.preferred_username ||
                   null;
  
  console.log('Extracted username:', username);
  return username;
}

/**
 * Upgrade guest account request body
 */
interface UpgradeGuestRequest {
  email: string;
  password: string;
  fullName: string;
}

/**
 * Validate password meets Cognito requirements
 */
function validatePassword(password: string): { valid: boolean; message?: string } {
  if (password.length < 8) {
    return { valid: false, message: 'Password must be at least 8 characters' };
  }
  if (!/[a-z]/.test(password)) {
    return { valid: false, message: 'Password must contain a lowercase letter' };
  }
  if (!/[A-Z]/.test(password)) {
    return { valid: false, message: 'Password must contain an uppercase letter' };
  }
  if (!/[0-9]/.test(password)) {
    return { valid: false, message: 'Password must contain a number' };
  }
  return { valid: true };
}

/**
 * Validate email format
 */
function validateEmail(email: string): boolean {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email) && !email.includes('@thinktank.guest');
}

/**
 * Main handler for auth operations
 */
export async function handler(event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> {
  console.log('Auth request received:', JSON.stringify(event, null, 2));

  const method = event.httpMethod;
  const path = event.path;

  try {
    // PATCH /auth/upgrade - Upgrade guest account to full account
    if (method === 'PATCH' && path === '/auth/upgrade') {
      return await handleUpgradeGuestAccount(event);
    }

    // OPTIONS for CORS preflight
    if (method === 'OPTIONS') {
      return createResponse(200, { message: 'OK' });
    }

    return createErrorResponse(404, 'Not Found', `Route not found: ${method} ${path}`);
  } catch (error) {
    console.error('Error handling auth request:', error);
    return createErrorResponse(
      500,
      'Internal Server Error',
      error instanceof Error ? error.message : 'Unknown error'
    );
  }
}

/**
 * Handle upgrading a guest account to a full account
 */
async function handleUpgradeGuestAccount(
  event: APIGatewayProxyEvent
): Promise<APIGatewayProxyResult> {
  // Validate user is authenticated
  const userId = getUserId(event);
  const currentUsername = getUsername(event);
  const claims = event.requestContext.authorizer?.claims;
  
  // Get cognito:username which is the actual Cognito username
  const cognitoUsername = claims?.['cognito:username'] || currentUsername;

  if (!userId) {
    return createErrorResponse(401, 'Unauthorized', 'User ID not found in token');
  }
  
  if (!cognitoUsername) {
    console.error('Could not extract username from claims:', JSON.stringify(claims));
    return createErrorResponse(401, 'Unauthorized', 'Username not found in token');
  }

  // Check if this is a guest account (email ends with @thinktank.guest)
  const userEmail = currentUsername || '';
  if (!userEmail.endsWith('@thinktank.guest')) {
    console.log('Not a guest account, email:', userEmail);
    return createErrorResponse(400, 'Bad Request', 'Only guest accounts can be upgraded');
  }
  
  console.log('Upgrading guest account - userId:', userId, 'cognitoUsername:', cognitoUsername, 'email:', userEmail);

  // Parse request body
  if (!event.body) {
    return createErrorResponse(400, 'Bad Request', 'Request body is required');
  }

  let data: UpgradeGuestRequest;
  try {
    data = JSON.parse(event.body);
  } catch (parseError) {
    console.error('Failed to parse request body:', event.body);
    return createErrorResponse(400, 'Bad Request', 'Invalid JSON in request body');
  }
  
  const { email, password, fullName } = data;
  console.log('Upgrade request for email:', email, 'fullName:', fullName);

  // Validate required fields
  if (!email || !password || !fullName) {
    return createErrorResponse(400, 'Bad Request', 'email, password, and fullName are required');
  }

  // Validate email format and ensure it's not a guest email
  if (!validateEmail(email)) {
    return createErrorResponse(400, 'Bad Request', 'Invalid email address');
  }

  // Validate password
  const passwordValidation = validatePassword(password);
  if (!passwordValidation.valid) {
    return createErrorResponse(400, 'Bad Request', passwordValidation.message!);
  }

  const userPoolId = process.env.USER_POOL_ID;
  if (!userPoolId) {
    console.error('USER_POOL_ID environment variable not set');
    return createErrorResponse(500, 'Internal Server Error', 'Server configuration error');
  }

  try {
    // Update user attributes (email, name)
    // Note: We use the cognitoUsername to identify the user (this is the actual Cognito username)
    console.log(`Calling AdminUpdateUserAttributesCommand for user: ${cognitoUsername}`);
    await cognitoClient.send(
      new AdminUpdateUserAttributesCommand({
        UserPoolId: userPoolId,
        Username: cognitoUsername,
        UserAttributes: [
          { Name: 'email', Value: email },
          { Name: 'name', Value: fullName },
          { Name: 'email_verified', Value: 'true' },
        ],
      })
    );

    console.log(`Updated user attributes for ${userId}`);

    // Set new password
    console.log(`Calling AdminSetUserPasswordCommand for user: ${cognitoUsername}`);
    await cognitoClient.send(
      new AdminSetUserPasswordCommand({
        UserPoolId: userPoolId,
        Username: cognitoUsername,
        Password: password,
        Permanent: true,
      })
    );

    console.log(`Updated password for ${userId}`);

    // Return success
    // The client will need to sign in again with the new credentials
    return createResponse(200, {
      success: true,
      message: 'Account upgraded successfully. Please sign in with your new credentials.',
    });
  } catch (error) {
    console.error('Error upgrading guest account:', error);

    // Handle specific Cognito errors
    if (error instanceof Error) {
      if (error.name === 'AliasExistsException') {
        return createErrorResponse(
          409,
          'Conflict',
          'An account with this email already exists'
        );
      }
      if (error.name === 'InvalidPasswordException') {
        return createErrorResponse(400, 'Bad Request', 'Password does not meet requirements');
      }
    }

    return createErrorResponse(
      500,
      'Internal Server Error',
      error instanceof Error ? error.message : 'Failed to upgrade account'
    );
  }
}
