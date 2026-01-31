# ThinkTank API - OpenAPI/Swagger Documentation

This folder contains the OpenAPI 3.0 specification for the ThinkTank API.

## Files

- `thinktank-api.yaml` - Complete OpenAPI 3.0 specification

## Viewing the Documentation

### Option 1: Swagger Editor (Online)
1. Go to [Swagger Editor](https://editor.swagger.io/)
2. File > Import File > Select `thinktank-api.yaml`

### Option 2: Swagger UI (Local)
```bash
# Using Docker
docker run -p 8080:8080 -e SWAGGER_JSON=/api/thinktank-api.yaml -v $(pwd):/api swaggerapi/swagger-ui
```

### Option 3: VS Code Extension
Install the "OpenAPI (Swagger) Editor" extension for VS Code.

## API Endpoints

### Authentication
All endpoints require a valid Cognito JWT token:
```
Authorization: Bearer <id_token>
```

### Chat
- `POST /chat` - Send message to AI (non-streaming)

### Models
- `GET /models` - List available AI models

### Conversations
- `GET /conversations` - List all conversations
- `POST /conversations` - Create new conversation
- `GET /conversations/{id}` - Get conversation with messages
- `PUT /conversations/{id}` - Update conversation
- `DELETE /conversations/{id}` - Delete conversation
- `POST /conversations/{id}/messages` - Add message

### Streaming
- `POST` to Lambda Function URL - Streaming chat responses (SSE)

## Server URLs

- **Production API**: `https://dguk8v0urb.execute-api.us-east-1.amazonaws.com/prod`
- **Streaming**: `https://krbsjrapw4xtourdlsd2callgq0kawoo.lambda-url.us-east-1.on.aws`
