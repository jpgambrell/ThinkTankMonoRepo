# ThinkTank AWS Backend

This directory contains the AWS infrastructure and Lambda functions for the ThinkTank macOS application.

## Architecture

- **Cognito**: User authentication and authorization (auto-confirm enabled)
- **API Gateway**: REST API endpoints
- **Lambda**: Serverless functions for business logic
- **Bedrock**: AI model access (Claude, Titan, Llama, Mistral)

### Authentication Flow

Users are **automatically confirmed** upon registration - no email verification required. A PreSignUp Lambda trigger auto-confirms users and marks their email as verified, providing a frictionless signup experience.

## Project Structure

```
AWS_Services/
├── cdk/                    # CDK infrastructure code
│   ├── bin/
│   │   └── app.ts         # CDK app entry point
│   └── lib/
│       ├── cognito-stack.ts  # Cognito User Pool
│       └── api-stack.ts      # API Gateway + Lambda
├── lambda/                 # Lambda function code
│   ├── chat/              # POST /chat - Bedrock integration
│   ├── models/            # GET /models - List models
│   └── shared/            # Shared utilities and types
└── test/                  # Tests
```

## Prerequisites

1. **AWS CLI** configured with appropriate credentials
2. **Node.js** 20+ and npm
3. **AWS CDK** CLI installed globally: `npm install -g aws-cdk`
4. **AWS Account** with Bedrock access enabled

## Setup

1. Install dependencies:
   ```bash
   cd AWS_Services
   npm install
   ```

2. Bootstrap CDK (first time only):
   ```bash
   cdk bootstrap
   ```

3. Build TypeScript code:
   ```bash
   npm run build
   ```

## Deployment

### Deploy all stacks:
```bash
npm run deploy
```

### Deploy specific stack:
```bash
cdk deploy ThinkTankCognitoStack
cdk deploy ThinkTankApiStack
```

### View differences before deploying:
```bash
npm run diff
```

### Synthesize CloudFormation templates:
```bash
npm run synth
```

## API Endpoints

After deployment, you'll get an API Gateway URL. Endpoints:

### POST /chat
Send a message to an AI model via Bedrock.

**Request:**
```json
{
  "conversationId": "optional-id",
  "modelId": "anthropic.claude-3-5-sonnet",
  "messages": [
    {
      "role": "user",
      "content": "Hello, how are you?"
    }
  ]
}
```

**Response:**
```json
{
  "conversationId": "conv_123456",
  "message": {
    "role": "assistant",
    "content": "I'm doing well, thank you!"
  },
  "usage": {
    "inputTokens": 10,
    "outputTokens": 15
  }
}
```

### GET /models
List available Bedrock models for the user.

**Response:**
```json
{
  "models": [
    {
      "modelId": "anthropic.claude-3-5-sonnet",
      "displayName": "Claude 3.5 Sonnet",
      "provider": "Anthropic",
      "maxTokens": 200000,
      "streaming": true
    }
  ]
}
```

## Authentication

All API endpoints require a valid Cognito JWT token in the `Authorization` header:

```
Authorization: Bearer <id_token>
```

## Environment Variables

Lambda functions receive these environment variables:
- `USER_POOL_ID` - Cognito User Pool ID
- `REGION` - AWS region

## Development

### Watch mode for TypeScript compilation:
```bash
npm run watch
```

### Run tests:
```bash
npm test
```

## Outputs

After deployment, CDK will output:
- **UserPoolId**: Cognito User Pool ID
- **UserPoolClientId**: App Client ID for macOS app
- **ApiUrl**: API Gateway base URL

Save these values for configuring the macOS application.

## Cleanup

To remove all resources:
```bash
cdk destroy --all
```

⚠️ **Warning**: The Cognito User Pool has a `RETAIN` removal policy and won't be deleted automatically.

## Cost Considerations

- **Cognito**: Free tier covers 50,000 MAUs
- **API Gateway**: $3.50 per million requests
- **Lambda**: Free tier covers 1M requests/month
- **Bedrock**: Pay per token (varies by model)

## Security Notes

1. Never commit AWS credentials
2. Use least-privilege IAM policies
3. Enable CloudWatch logging for debugging
4. Consider adding rate limiting per user
5. Restrict CORS origins in production
6. Enable AWS WAF for API protection

## Support

For issues or questions, refer to:
- [AWS CDK Documentation](https://docs.aws.amazon.com/cdk/)
- [Amazon Bedrock Documentation](https://docs.aws.amazon.com/bedrock/)
- [AWS Lambda Documentation](https://docs.aws.amazon.com/lambda/)
