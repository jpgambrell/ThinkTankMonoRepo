#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { CognitoStack } from '../lib/cognito-stack';
import { DatabaseStack } from '../lib/database-stack';
import { ApiStack } from '../lib/api-stack';

const app = new cdk.App();

// Get environment configuration
const env = {
  account: process.env.CDK_DEFAULT_ACCOUNT,
  region: process.env.CDK_DEFAULT_REGION || 'us-east-1',
};

// Create Cognito stack (authentication)
const cognitoStack = new CognitoStack(app, 'ThinkTankCognitoStack', {
  env,
  description: 'ThinkTank Cognito User Pool and Identity Provider',
});

// Create Database stack (DynamoDB for chat history)
const databaseStack = new DatabaseStack(app, 'ThinkTankDatabaseStack', {
  env,
  description: 'ThinkTank DynamoDB tables for chat history storage',
});

// Create API stack (API Gateway + Lambda + OpenRouter)
const apiStack = new ApiStack(app, 'ThinkTankApiStack', {
  env,
  description: 'ThinkTank API Gateway, Lambda Functions, and OpenRouter Integration',
  userPool: cognitoStack.userPool,
  chatHistoryTable: databaseStack.chatHistoryTable,
});

// Add tags to all resources
cdk.Tags.of(app).add('Project', 'ThinkTank');
cdk.Tags.of(app).add('Environment', process.env.ENVIRONMENT || 'dev');

app.synth();
