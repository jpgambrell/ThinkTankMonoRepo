import * as cdk from 'aws-cdk-lib';
import * as cognito from 'aws-cdk-lib/aws-cognito';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import { Construct } from 'constructs';
import * as path from 'path';

export class CognitoStack extends cdk.Stack {
  public readonly userPool: cognito.UserPool;
  public readonly userPoolClient: cognito.IUserPoolClient;

  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // Lambda function to auto-confirm users on sign-up
    const preSignUpTrigger = new lambda.Function(this, 'PreSignUpTrigger', {
      runtime: lambda.Runtime.NODEJS_20_X,
      handler: 'index.handler',
      code: lambda.Code.fromInline(`
        exports.handler = async (event) => {
          // Auto-confirm user
          event.response.autoConfirmUser = true;
          
          // Auto-verify email (mark as verified without sending code)
          event.response.autoVerifyEmail = true;
          
          return event;
        };
      `),
      description: 'Auto-confirm users on sign-up',
    });

    // Create Cognito User Pool
    this.userPool = new cognito.UserPool(this, 'ThinkTankUserPool', {
      userPoolName: 'thinktank-users',
      selfSignUpEnabled: true,
      signInAliases: {
        email: true,
        username: false,
      },
      // Remove autoVerify - we'll handle this in the Lambda trigger
      lambdaTriggers: {
        preSignUp: preSignUpTrigger,
      },
      standardAttributes: {
        email: {
          required: true,
          mutable: true,  // Must be true to allow guest account email upgrades
        },
        fullname: {
          required: false,
          mutable: true,
        },
      },
      passwordPolicy: {
        minLength: 8,
        requireLowercase: true,
        requireUppercase: true,
        requireDigits: true,
        requireSymbols: false,
      },
      accountRecovery: cognito.AccountRecovery.EMAIL_ONLY,
      removalPolicy: cdk.RemovalPolicy.RETAIN, // Keep user data on stack deletion
    });

    // Create User Pool Client for the macOS app using L1 construct for precise control
    const cfnUserPoolClient = new cognito.CfnUserPoolClient(this, 'ThinkTankAppClient', {
      userPoolId: this.userPool.userPoolId,
      clientName: 'thinktank-macos-app',
      
      // Auth flows - username/password only, no OAuth
      explicitAuthFlows: [
        'ALLOW_USER_PASSWORD_AUTH',
        'ALLOW_USER_SRP_AUTH',
        'ALLOW_REFRESH_TOKEN_AUTH',
      ],
      
      // Token validity
      refreshTokenValidity: 30, // days
      accessTokenValidity: 60, // minutes
      idTokenValidity: 60, // minutes
      tokenValidityUnits: {
        refreshToken: 'days',
        accessToken: 'minutes',
        idToken: 'minutes',
      },
      
      // Security settings
      preventUserExistenceErrors: 'ENABLED',
      generateSecret: false,
      enableTokenRevocation: true,
      
      // No OAuth flows - explicitly omit AllowedOAuthFlows and related properties
    });

    // Wrap in IUserPoolClient interface for use in other stacks
    this.userPoolClient = cognito.UserPoolClient.fromUserPoolClientId(
      this,
      'ThinkTankAppClientRef',
      cfnUserPoolClient.ref
    );

    // Outputs for use in other stacks and app configuration
    new cdk.CfnOutput(this, 'UserPoolId', {
      value: this.userPool.userPoolId,
      description: 'Cognito User Pool ID',
      exportName: 'ThinkTankUserPoolId',
    });

    new cdk.CfnOutput(this, 'UserPoolArn', {
      value: this.userPool.userPoolArn,
      description: 'Cognito User Pool ARN',
    });

    new cdk.CfnOutput(this, 'UserPoolClientId', {
      value: this.userPoolClient.userPoolClientId,
      description: 'Cognito User Pool Client ID',
      exportName: 'ThinkTankUserPoolClientId',
    });

    new cdk.CfnOutput(this, 'CognitoRegion', {
      value: this.region,
      description: 'AWS Region for Cognito',
    });
  }
}
