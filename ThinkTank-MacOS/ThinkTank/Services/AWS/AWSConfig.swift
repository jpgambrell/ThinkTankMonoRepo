import Foundation

/// AWS configuration values from deployed infrastructure
struct AWSConfig {
    // Cognito Configuration
    static let cognitoUserPoolId = "us-east-1_L0uXjT29g"
    static let cognitoClientId = "2ocgk8pjnp2ofkjpmfgq75iuls"
    static let cognitoRegion = "us-east-1"
    
    // API Gateway Configuration
    static let apiBaseUrl = "https://dguk8v0urb.execute-api.us-east-1.amazonaws.com/prod/"
    static let chatEndpoint = "\(apiBaseUrl)chat"
    static let modelsEndpoint = "\(apiBaseUrl)models"
    
    // API Configuration
    static let requestTimeout: TimeInterval = 30
    static let maxRetries = 3
}
