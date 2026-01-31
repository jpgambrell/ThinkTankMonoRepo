# ThinkTank API - Postman Collection

This folder contains the Postman collection and environment for testing the ThinkTank API.

## Files

- `ThinkTank-API.postman_collection.json` - Complete API collection
- `ThinkTank-Environment.postman_environment.json` - Environment variables

## Import Instructions

1. Open Postman
2. Click **Import** button
3. Select both files:
   - `ThinkTank-API.postman_collection.json`
   - `ThinkTank-Environment.postman_environment.json`
4. Click **Import**

## Setup

1. Select **ThinkTank Environment** from the environment dropdown (top right)
2. Edit the environment and set:
   - `userEmail` - Your registered email
   - `userPassword` - Your password

## Usage

### 1. Authenticate
1. Open **Auth > Sign In**
2. Update the email and password in the request body
3. Send the request
4. Tokens are automatically saved to collection variables

### 2. Test Endpoints
After authentication, all other requests will automatically use your token.

#### Recommended Test Flow:
1. **Models > List Models** - Verify API access
2. **Conversations > Create Conversation** - Create a new chat
3. **Chat > Send Chat Message** - Send a message to AI
4. **Conversations > Get Conversation** - View saved messages
5. **Conversations > List Conversations** - See all your chats

## Collection Structure

```
ThinkTank API/
├── Auth/
│   ├── Sign In
│   ├── Sign Up
│   └── Refresh Token
├── Models/
│   └── List Models
├── Chat/
│   ├── Send Chat Message
│   ├── Send Chat Message (with conversationId)
│   └── Send Chat Message (Streaming)
└── Conversations/
    ├── List Conversations
    ├── Create Conversation
    ├── Get Conversation
    ├── Update Conversation
    ├── Delete Conversation
    └── Add Message to Conversation
```

## Variables

| Variable | Description |
|----------|-------------|
| `baseUrl` | API Gateway URL |
| `streamingUrl` | Lambda Function URL for streaming |
| `cognitoUrl` | Cognito endpoint |
| `userPoolClientId` | Cognito client ID |
| `id_token` | JWT token (auto-populated on sign in) |
| `conversationId` | Current conversation ID (auto-populated) |

## Notes

- Tokens expire after 60 minutes - use **Refresh Token** to get new tokens
- The streaming endpoint returns Server-Sent Events (SSE) - Postman shows raw output
- Conversation IDs are automatically saved when creating conversations or sending chat messages
