# Product Requirements Document: macOS AI Chatbot Application

## Overview

A native macOS desktop application for interacting with AI language models through a clean, intuitive chat interface, powered by AWS cloud services for authentication and AI model access.

---

## Architecture

### Cloud Infrastructure (AWS)

**Authentication & User Management**
- Amazon Cognito User Pool for user registration, login, and session management
- Support for email/password authentication
- Secure token refresh handling with Cognito JWT tokens
- Optional: Social identity providers (Google, Apple) via Cognito federation

**AI Model Access**
- Amazon Bedrock for LLM API access
- Supported models: Claude (Anthropic), Titan (Amazon), Llama, Mistral, and other Bedrock-available models
- Model selection exposed to user based on account permissions/availability

**Microservices Layer**
- AWS Lambda functions written in TypeScript
- API Gateway (REST or HTTP API) as the entry point
- Lambda responsibilities:
  - Validate Cognito tokens and authorize requests
  - Proxy and transform requests to Bedrock APIs
  - Handle conversation context management if needed
  - Rate limiting and usage tracking per user
  - Error handling and logging to CloudWatch

### Data Flow

```
macOS App → API Gateway → Lambda (TypeScript) → Bedrock
                ↓
            Cognito (auth validation)
```

---

## Core Layout

### Two-Panel Design

**Left Sidebar (~250px)**
- List of conversation threads, sorted by most recent
- Each item displays: conversation title/preview, timestamp, LLM used
- "New Chat" button prominently placed at top
- Search/filter functionality for finding past conversations
- Right-click context menu for rename, delete, export options
- User profile/account section at bottom (logout, settings access)

**Main Content Area (flexible width)**
- Active conversation display with message history
- Clear visual distinction between user messages and AI responses
- Auto-scroll to newest messages with scroll-up access to history
- Timestamp and model indicator per message (collapsible)
- Loading/streaming indicator during AI response generation

### Input Area (bottom of main content)

- Multi-line text input field with auto-expand
- LLM selector dropdown populated from Bedrock available models
- Send button (also supports Cmd+Enter to submit)
- Token/character counter
- Optional: attachment button, settings gear icon

---

## Functional Requirements

### Authentication
1. Login/registration screens with Cognito integration
2. Secure token storage in macOS Keychain
3. Automatic token refresh before expiration
4. Logout functionality with token invalidation
5. Password reset flow via Cognito

### Conversation Management
1. Create, rename, delete, and search conversations
2. Sync conversation metadata to cloud (optional: full sync or local-only with cloud auth)
3. Export conversations as markdown, JSON, or PDF

### Model Selection
1. Fetch available Bedrock models dynamically from Lambda endpoint
2. Persist last-used model choice per user
3. Allow per-conversation model switching
4. Display model capabilities/context limits where relevant

### Message Handling
1. Support markdown rendering in responses
2. Code blocks with syntax highlighting and copy button
3. Streaming responses from Bedrock (if supported by model)
4. Error states with retry option
5. Copy entire response to clipboard

### Settings
1. Account management (email, password change)
2. Default model preference
3. Appearance (light/dark mode, font size)
4. Keyboard shortcut customization

---

## Technical Specifications

### macOS Application
- **Language**: Swift
- **UI Framework**: SwiftUI
- **Minimum OS**: macOS 13 (Ventura)
- **Authentication SDK**: AWS Amplify for Swift or direct Cognito API integration
- **Networking**: Native URLSession with async/await
- **Local Storage**: Core Data or SwiftData for conversation history
- **Security**: Keychain for tokens, certificate pinning for API calls

### AWS Lambda Microservice
- **Runtime**: Node.js 18+ with TypeScript
- **Framework**: Minimal (direct handler) or lightweight (Hono, Fastify)
- **Responsibilities**:
  - `POST /chat` — Send message to Bedrock, return response (streaming if possible)
  - `GET /models` — Return list of available Bedrock models for user
  - `POST /conversations` — Save/sync conversation metadata (optional)
  - `GET /conversations` — Retrieve user's conversation list (optional)
- **Authentication**: Cognito authorizer on API Gateway
- **Logging**: CloudWatch with structured JSON logs
- **Error Handling**: Standardized error response format

### AWS Infrastructure
- **API Gateway**: HTTP API with Cognito JWT authorizer
- **Cognito**: User Pool with app client (no secret for public client)
- **Bedrock**: Model access configured via IAM roles
- **IAM**: Lambda execution role with Bedrock invoke permissions
- **Optional**: DynamoDB for conversation persistence, S3 for file attachments

---

## Security Considerations

1. All API communication over HTTPS
2. Cognito tokens validated on every Lambda invocation
3. No AWS credentials stored in the macOS app
4. Bedrock access scoped to specific models via IAM policy
5. Input sanitization in Lambda before Bedrock calls
6. Rate limiting at API Gateway level

---

## Future Considerations

- Conversation sync across devices via DynamoDB
- File/image attachments with S3 storage
- Usage analytics and cost tracking per user
- Team/organization accounts with shared conversations
- Plugin system for custom model integrations

---

## API Contracts

### POST /chat

**Request**
```json
{
  "conversationId": "string (optional, omit for new conversation)",
  "modelId": "string (e.g., 'anthropic.claude-3-sonnet-20240229-v1:0')",
  "messages": [
    {
      "role": "user | assistant",
      "content": "string"
    }
  ]
}
```

**Response**
```json
{
  "conversationId": "string",
  "message": {
    "role": "assistant",
    "content": "string"
  },
  "usage": {
    "inputTokens": 0,
    "outputTokens": 0
  }
}
```

### GET /models

**Response**
```json
{
  "models": [
    {
      "modelId": "string",
      "displayName": "string",
      "provider": "string",
      "maxTokens": 0,
      "streaming": true
    }
  ]
}
```

### GET /conversations

**Response**
```json
{
  "conversations": [
    {
      "conversationId": "string",
      "title": "string",
      "modelId": "string",
      "createdAt": "ISO8601",
      "updatedAt": "ISO8601",
      "messageCount": 0
    }
  ]
}
```

---

## Development Milestones

### Phase 1: Foundation
- AWS infrastructure setup (Cognito, API Gateway, Lambda skeleton)
- macOS app project setup with SwiftUI
- Authentication flow (login, register, logout)

### Phase 2: Core Chat
- Basic chat UI (two-panel layout)
- Lambda integration with Bedrock
- Single conversation flow (no persistence)

### Phase 3: Conversation Management
- Local conversation storage
- Conversation list UI
- New chat, rename, delete functionality

### Phase 4: Polish
- Streaming responses
- Markdown rendering and code highlighting
- Settings screen
- Error handling and edge cases

### Phase 5: Optional Enhancements
- Cloud conversation sync
- Export functionality
- Usage tracking
