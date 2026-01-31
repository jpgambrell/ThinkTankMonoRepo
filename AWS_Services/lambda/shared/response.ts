// Response utilities for Lambda functions

export interface LambdaResponse {
  statusCode: number;
  headers: Record<string, string>;
  body: string;
}

export const corsHeaders = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*', // Restrict in production
  'Access-Control-Allow-Headers': 'Content-Type,Authorization',
  'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS',
};

/**
 * Create a successful response with any status code
 */
export function createResponse<T>(statusCode: number, data: T): LambdaResponse {
  return {
    statusCode,
    headers: corsHeaders,
    body: JSON.stringify(data),
  };
}

/**
 * Create an error response
 */
export function createErrorResponse(
  statusCode: number,
  errorType: string,
  message: string
): LambdaResponse {
  return {
    statusCode,
    headers: corsHeaders,
    body: JSON.stringify({
      error: errorType,
      message,
      statusCode,
    }),
  };
}

export function success<T>(data: T): LambdaResponse {
  return {
    statusCode: 200,
    headers: corsHeaders,
    body: JSON.stringify(data),
  };
}

export function error(statusCode: number, message: string, error?: string): LambdaResponse {
  return {
    statusCode,
    headers: corsHeaders,
    body: JSON.stringify({
      error: error || 'Error',
      message,
      statusCode,
    }),
  };
}

export function badRequest(message: string): LambdaResponse {
  return error(400, message, 'BadRequest');
}

export function unauthorized(message: string = 'Unauthorized'): LambdaResponse {
  return error(401, message, 'Unauthorized');
}

export function forbidden(message: string = 'Forbidden'): LambdaResponse {
  return error(403, message, 'Forbidden');
}

export function notFound(message: string = 'Not Found'): LambdaResponse {
  return error(404, message, 'NotFound');
}

export function internalError(message: string = 'Internal Server Error'): LambdaResponse {
  return error(500, message, 'InternalServerError');
}
