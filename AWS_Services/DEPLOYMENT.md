# ThinkTank AWS Deployment Guide

## Quick Start

### 1. Prerequisites

Ensure you have:
- AWS CLI configured with credentials: `aws configure`
- AWS account with Bedrock access enabled in your region
- Node.js 20+ installed

### 2. Enable Bedrock Models

**Important**: Before deploying, enable Bedrock model access in AWS Console:

1. Go to AWS Console → Amazon Bedrock → Model access
2. Enable access for these models:
   - **Anthropic Claude 3.5 Sonnet**
   - **Anthropic Claude 3 Opus**  
   - **Anthropic Claude 3 Haiku**
   - **Amazon Titan Text Express**
   - **Meta Llama 3 70B** (optional)
   - **Mistral Mixtral 8x7B** (optional)

⚠️ Model access approval can take a few minutes to several hours depending on your AWS account status.

### 3. Deploy Infrastructure

```bash
cd AWS_Services

# Bootstrap CDK (first time only)
cdk bootstrap

# Deploy all stacks
npm run deploy

# Or deploy individually
cdk deploy ThinkTankCognitoStack
cdk deploy ThinkTankApiStack
```

### 4. Save Configuration

After deployment, save these outputs for the macOS app:

```bash
# From CloudFormation outputs:
- UserPoolId: us-east-1_XXXXXXX
- UserPoolClientId: xxxxxxxxxxxxxxxxxxxxxxxxxx
- CognitoRegion: us-east-1
- ApiUrl: https://xxxxxxxxxx.execute-api.us-east-1.amazonaws.com/prod/
```

### 5. Test the API

```bash
# Register a test user (replace with your email)
# NOTE: User is auto-confirmed - no email verification needed!
aws cognito-idp sign-up \
  --client-id YOUR_CLIENT_ID \
  --username test@example.com \
  --password TestPassword123! \
  --user-attributes Name=email,Value=test@example.com

# Sign in immediately to get tokens (no confirmation step needed)
aws cognito-idp initiate-auth \
  --client-id YOUR_CLIENT_ID \
  --auth-flow USER_PASSWORD_AUTH \
  --auth-parameters USERNAME=test@example.com,PASSWORD=TestPassword123!

# Test /models endpoint
curl -H "Authorization: Bearer YOUR_ID_TOKEN" \
  YOUR_API_URL/models

# Test /chat endpoint
curl -X POST YOUR_API_URL/chat \
  -H "Authorization: Bearer YOUR_ID_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "modelId": "anthropic.claude-3-5-sonnet",
    "messages": [
      {
        "role": "user",
        "content": "Hello! Tell me a joke."
      }
    ]
  }'
```

## Cost Estimate

For development/testing with moderate usage:

| Service | Cost |
|---------|------|
| Cognito | Free (< 50K MAU) |
| API Gateway | ~$0.01/day |
| Lambda | Free tier |
| Bedrock (Claude 3.5 Sonnet) | ~$0.003/1K input tokens |
| CloudWatch Logs | ~$0.01/day |

**Estimated monthly cost**: $5-20 depending on usage

## Monitoring

View logs in CloudWatch:
```bash
aws logs tail /aws/lambda/ThinkTankApiStack-ChatFunction --follow
aws logs tail /aws/lambda/ThinkTankApiStack-ModelsFunction --follow
```

## Troubleshooting

### "Model not found" error
- Ensure Bedrock model access is enabled in AWS Console
- Check that you're in the correct region
- Wait a few minutes after enabling model access

### "AccessDeniedException" from Bedrock
- Verify IAM role has `bedrock:InvokeModel` permission
- Check that the Lambda execution role is correctly attached

### API returns 401 Unauthorized
- Verify Cognito tokens are valid and not expired
- Ensure `Authorization: Bearer <token>` header is set
- Check that User Pool ID matches the authorizer configuration

### High Lambda cold start times
- First invocation can take 3-5 seconds
- Consider provisioned concurrency for production

## Cleanup

To remove all resources:
```bash
cd AWS_Services
cdk destroy --all
```

⚠️ **Note**: Cognito User Pool will be retained (not deleted) to prevent accidental data loss.

## Next Steps

1. Configure the macOS app with the deployment outputs
2. Implement authentication screens in the Swift app
3. Replace mock chat service with real API calls
4. Add conversation persistence (optional: DynamoDB)
5. Set up CI/CD pipeline for automated deployments

## Production Checklist

Before going to production:

- [ ] Restrict CORS origins to your app only
- [ ] Add rate limiting per user
- [ ] Enable AWS WAF for API Gateway
- [ ] Set up CloudWatch alarms for errors
- [ ] Configure backup for Cognito User Pool
- [ ] Review and optimize Lambda memory/timeout
- [ ] Enable API Gateway access logs
- [ ] Add DynamoDB for conversation storage
- [ ] Implement proper error handling in app
- [ ] Set up custom domain for API
- [ ] Configure CloudFront for API caching (optional)
- [ ] Review IAM policies for least privilege
- [ ] Enable AWS X-Ray for tracing
- [ ] Set up cost alerts in AWS Budgets
