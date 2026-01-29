import * as cdk from 'aws-cdk-lib';
import * as apigateway from 'aws-cdk-lib/aws-apigateway';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import { NodejsFunction } from 'aws-cdk-lib/aws-lambda-nodejs';
import * as logs from 'aws-cdk-lib/aws-logs';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as cognito from 'aws-cdk-lib/aws-cognito';
import { Construct } from 'constructs';
import * as path from 'path';

interface ApiStackProps extends cdk.StackProps {
  userPool: cognito.UserPool;
}

export class ApiStack extends cdk.Stack {
  public readonly api: apigateway.RestApi;

  constructor(scope: Construct, id: string, props: ApiStackProps) {
    super(scope, id, props);

    // Create IAM role for Lambda functions with Bedrock access
    const lambdaRole = new iam.Role(this, 'ThinkTankLambdaRole', {
      assumedBy: new iam.ServicePrincipal('lambda.amazonaws.com'),
      description: 'Execution role for ThinkTank Lambda functions',
      managedPolicies: [
        iam.ManagedPolicy.fromAwsManagedPolicyName('service-role/AWSLambdaBasicExecutionRole'),
      ],
    });

    // Add Bedrock permissions
    lambdaRole.addToPolicy(
      new iam.PolicyStatement({
        effect: iam.Effect.ALLOW,
        actions: [
          'bedrock:InvokeModel',
          'bedrock:InvokeModelWithResponseStream',
          'bedrock:ListFoundationModels',
          'bedrock:GetFoundationModel',
        ],
        resources: ['*'],
      })
    );

    // Add AWS Marketplace permissions for model access
    lambdaRole.addToPolicy(
      new iam.PolicyStatement({
        effect: iam.Effect.ALLOW,
        actions: [
          'aws-marketplace:ViewSubscriptions',
          'aws-marketplace:Subscribe',
          'aws-marketplace:Unsubscribe',
        ],
        resources: ['*'],
      })
    );

    // Common Lambda environment variables
    const commonEnvironment = {
      USER_POOL_ID: props.userPool.userPoolId,
      REGION: this.region,
    };

    // POST /chat - Send message to Bedrock (NodejsFunction auto-compiles TypeScript)
    const chatFunction = new NodejsFunction(this, 'ChatFunction', {
      entry: path.join(__dirname, '../../lambda/chat/index.ts'),
      handler: 'handler',
      runtime: lambda.Runtime.NODEJS_20_X,
      role: lambdaRole,
      timeout: cdk.Duration.seconds(30),
      memorySize: 512,
      environment: commonEnvironment,
      logRetention: logs.RetentionDays.ONE_WEEK,
      bundling: {
        externalModules: ['@aws-sdk/*'], // Use Lambda's built-in AWS SDK
        minify: false,
        sourceMap: true,
        forceDockerBundling: false, // Use local esbuild, not Docker
      },
    });

    // GET /models - List available Bedrock models
    const modelsFunction = new NodejsFunction(this, 'ModelsFunction', {
      entry: path.join(__dirname, '../../lambda/models/index.ts'),
      handler: 'handler',
      runtime: lambda.Runtime.NODEJS_20_X,
      role: lambdaRole,
      timeout: cdk.Duration.seconds(10),
      memorySize: 256,
      environment: commonEnvironment,
      logRetention: logs.RetentionDays.ONE_WEEK,
      bundling: {
        externalModules: ['@aws-sdk/*'],
        minify: false,
        sourceMap: true,
        forceDockerBundling: false,
      },
    });

    // Create API Gateway with CORS
    this.api = new apigateway.RestApi(this, 'ThinkTankApi', {
      restApiName: 'ThinkTank API',
      description: 'API for ThinkTank macOS application',
      cloudWatchRole: true, // Enable CloudWatch role for logging
      deployOptions: {
        stageName: 'prod',
        throttlingRateLimit: 100,
        throttlingBurstLimit: 200,
        loggingLevel: apigateway.MethodLoggingLevel.INFO,
        dataTraceEnabled: true,
        metricsEnabled: true,
      },
      defaultCorsPreflightOptions: {
        allowOrigins: apigateway.Cors.ALL_ORIGINS, // Restrict in production
        allowMethods: apigateway.Cors.ALL_METHODS,
        allowHeaders: [
          'Content-Type',
          'Authorization',
          'X-Amz-Date',
          'X-Api-Key',
          'X-Amz-Security-Token',
        ],
        maxAge: cdk.Duration.days(1),
      },
    });

    // Create Cognito authorizer
    const authorizer = new apigateway.CognitoUserPoolsAuthorizer(this, 'CognitoAuthorizer', {
      cognitoUserPools: [props.userPool],
      identitySource: 'method.request.header.Authorization',
      authorizerName: 'ThinkTankAuthorizer',
    });

    // Common request validator
    const requestValidator = new apigateway.RequestValidator(this, 'RequestValidator', {
      restApi: this.api,
      validateRequestBody: true,
      validateRequestParameters: true,
    });

    // POST /chat endpoint
    const chatResource = this.api.root.addResource('chat');
    chatResource.addMethod('POST', new apigateway.LambdaIntegration(chatFunction), {
      authorizer,
      authorizationType: apigateway.AuthorizationType.COGNITO,
      requestValidator,
      requestModels: {
        'application/json': this.createChatRequestModel(),
      },
    });

    // GET /models endpoint
    const modelsResource = this.api.root.addResource('models');
    modelsResource.addMethod('GET', new apigateway.LambdaIntegration(modelsFunction), {
      authorizer,
      authorizationType: apigateway.AuthorizationType.COGNITO,
    });

    // Outputs
    new cdk.CfnOutput(this, 'ApiUrl', {
      value: this.api.url,
      description: 'API Gateway endpoint URL',
      exportName: 'ThinkTankApiUrl',
    });

    new cdk.CfnOutput(this, 'ApiId', {
      value: this.api.restApiId,
      description: 'API Gateway ID',
    });
  }

  private createChatRequestModel(): apigateway.Model {
    return new apigateway.Model(this, 'ChatRequestModel', {
      restApi: this.api,
      contentType: 'application/json',
      modelName: 'ChatRequest',
      schema: {
        type: apigateway.JsonSchemaType.OBJECT,
        properties: {
          conversationId: {
            type: apigateway.JsonSchemaType.STRING,
          },
          modelId: {
            type: apigateway.JsonSchemaType.STRING,
          },
          messages: {
            type: apigateway.JsonSchemaType.ARRAY,
            items: {
              type: apigateway.JsonSchemaType.OBJECT,
              properties: {
                role: {
                  type: apigateway.JsonSchemaType.STRING,
                  enum: ['user', 'assistant'],
                },
                content: {
                  type: apigateway.JsonSchemaType.STRING,
                },
              },
              required: ['role', 'content'],
            },
          },
        },
        required: ['modelId', 'messages'],
      },
    });
  }
}
