import Foundation

/// Real API client for ThinkTank backend
actor APIClient {
    private let authService = CognitoAuthService.shared
    
    // MARK: - Chat Endpoint
    
    struct ChatRequest: Codable {
        let conversationId: String?
        let modelId: String
        let messages: [MessageDTO]
    }
    
    struct MessageDTO: Codable {
        let role: String
        let content: String
    }
    
    struct ChatResponse: Codable {
        let conversationId: String
        let message: MessageDTO
        let usage: Usage?
        
        struct Usage: Codable {
            let inputTokens: Int
            let outputTokens: Int
        }
    }
    
    /// Send a message to the AI model
    func sendMessage(conversationId: String?, modelId: String, messages: [Message]) async throws -> Message {
        let endpoint = URL(string: AWSConfig.chatEndpoint)!
        
        // Convert messages to DTO format
        let messageDTOs = messages.map { msg in
            MessageDTO(role: msg.role.rawValue, content: msg.content)
        }
        
        let requestBody = ChatRequest(
            conversationId: conversationId,
            modelId: modelId,
            messages: messageDTOs
        )
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add authentication token
        let token = try await authService.getIdToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        request.timeoutInterval = AWSConfig.requestTimeout
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError(httpResponse.statusCode, errorMessage)
        }
        
        let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)
        
        // Convert response to Message model
        return Message(
            role: chatResponse.message.role == "assistant" ? .assistant : .user,
            content: chatResponse.message.content,
            timestamp: Date(),
            modelId: modelId
        )
    }
    
    // MARK: - Models Endpoint
    
    struct ModelsResponse: Codable {
        let models: [ModelDTO]
    }
    
    struct ModelDTO: Codable {
        let modelId: String
        let displayName: String
        let provider: String
        let maxTokens: Int
        let streaming: Bool
    }
    
    /// Fetch available AI models from the backend
    func fetchModels() async throws -> [AIModel] {
        let endpoint = URL(string: AWSConfig.modelsEndpoint)!
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        
        // Add authentication token
        let token = try await authService.getIdToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        request.timeoutInterval = AWSConfig.requestTimeout
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError(httpResponse.statusCode, errorMessage)
        }
        
        let modelsResponse = try JSONDecoder().decode(ModelsResponse.self, from: data)
        
        // Convert to AIModel objects
        return modelsResponse.models.map { dto in
            AIModel(
                id: dto.modelId,
                displayName: dto.displayName,
                provider: dto.provider,
                description: "Max tokens: \(dto.maxTokens)",
                maxTokens: dto.maxTokens,
                supportsStreaming: dto.streaming
            )
        }
    }
}

// MARK: - Error Types

enum APIError: LocalizedError {
    case invalidResponse
    case unauthorized
    case serverError(Int, String)
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Unauthorized - please sign in again"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        case .decodingError:
            return "Failed to decode server response"
        }
    }
}
