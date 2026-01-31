import * as cdk from 'aws-cdk-lib';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import { Construct } from 'constructs';

export class DatabaseStack extends cdk.Stack {
  public readonly chatHistoryTable: dynamodb.Table;

  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // Create DynamoDB table for chat history using single-table design
    // PK/SK patterns:
    //   - Conversations: PK = USER#<userId>, SK = CONV#<conversationId>
    //   - Messages: PK = CONV#<conversationId>, SK = MSG#<timestamp>#<messageId>
    this.chatHistoryTable = new dynamodb.Table(this, 'ChatHistoryTable', {
      tableName: 'thinktank-chat-history',
      partitionKey: { name: 'PK', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'SK', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      removalPolicy: cdk.RemovalPolicy.RETAIN, // Keep data on stack deletion
      pointInTimeRecovery: true, // Enable point-in-time recovery for data protection
    });

    // GSI for listing conversations sorted by updatedAt
    // GSI1PK = userId, GSI1SK = updatedAt (for listing conversations by most recent)
    this.chatHistoryTable.addGlobalSecondaryIndex({
      indexName: 'GSI1',
      partitionKey: { name: 'GSI1PK', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'GSI1SK', type: dynamodb.AttributeType.STRING },
      projectionType: dynamodb.ProjectionType.ALL,
    });

    // Outputs
    new cdk.CfnOutput(this, 'ChatHistoryTableName', {
      value: this.chatHistoryTable.tableName,
      description: 'DynamoDB table name for chat history',
      exportName: 'ThinkTankChatHistoryTableName',
    });

    new cdk.CfnOutput(this, 'ChatHistoryTableArn', {
      value: this.chatHistoryTable.tableArn,
      description: 'DynamoDB table ARN for chat history',
      exportName: 'ThinkTankChatHistoryTableArn',
    });
  }
}
