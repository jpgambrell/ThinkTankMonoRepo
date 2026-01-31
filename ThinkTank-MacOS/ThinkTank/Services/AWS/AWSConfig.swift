import Foundation

/// AWS configuration values from deployed infrastructure
/// Marked nonisolated for safe access from any isolation domain
let _awsApiBaseUrl = "https://dguk8v0urb.execute-api.us-east-1.amazonaws.com/prod/"

enum AWSConfig {
    // Cognito Configuration
    nonisolated static let cognitoUserPoolId = "us-east-1_L0uXjT29g"
    nonisolated static let cognitoClientId = "2ocgk8pjnp2ofkjpmfgq75iuls"
    nonisolated static let cognitoRegion = "us-east-1"
    
    // API Gateway Configuration
    nonisolated static let apiBaseUrl = _awsApiBaseUrl
    nonisolated static let chatEndpoint = _awsApiBaseUrl + "chat"
    nonisolated static let modelsEndpoint = _awsApiBaseUrl + "models"
    nonisolated static let conversationsEndpoint = _awsApiBaseUrl + "conversations"
    
    // Lambda Function URL for Streaming
    nonisolated static let streamingEndpoint = "https://krbsjrapw4xtourdlsd2callgq0kawoo.lambda-url.us-east-1.on.aws/"
    
    // API Configuration
    nonisolated static let requestTimeout: TimeInterval = 30
    nonisolated static let streamingTimeout: TimeInterval = 120
    nonisolated static let maxRetries: Int = 3
}
