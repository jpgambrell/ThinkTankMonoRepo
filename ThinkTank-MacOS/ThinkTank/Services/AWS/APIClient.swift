import Foundation

/// Real API client for ThinkTank backend
actor APIClient {
    
    /// Get the ID token from the auth service (accessing @MainActor from actor)
    private func getIdToken() async throws -> String {
        try await MainActor.run {
            // Access the @MainActor isolated shared instance
            CognitoAuthService.shared
        }.getIdToken()
    }
    
    // MARK: - Chat Endpoint
    
    struct ChatRequest: Codable {
        let conversationId: String?
        let modelId: String
        let messages: [MessageDTO]
        let stream: Bool?
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
    
    /// Streaming chunk from SSE response
    struct StreamChunk: Codable {
        let choices: [Choice]?
        let error: StreamError?
        
        struct Choice: Codable {
            let delta: Delta?
            let finishReason: String?
            
            enum CodingKeys: String, CodingKey {
                case delta
                case finishReason = "finish_reason"
            }
        }
        
        struct Delta: Codable {
            let content: String?
            let role: String?
        }
        
        struct StreamError: Codable {
            let message: String
        }
    }
    
    /// Send a message to the AI model (non-streaming)
    func sendMessage(conversationId: String?, modelId: String, messages: [Message]) async throws -> Message {
        let endpoint = URL(string: AWSConfig.chatEndpoint)!
        
        // Convert messages to DTO format
        let messageDTOs = messages.map { msg in
            MessageDTO(role: msg.role.rawValue, content: msg.content)
        }
        
        let requestBody = ChatRequest(
            conversationId: conversationId,
            modelId: modelId,
            messages: messageDTOs,
            stream: false
        )
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add authentication token
        let token = try await getIdToken()
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
    
    /// Check if streaming is available
    var isStreamingAvailable: Bool {
        !AWSConfig.streamingEndpoint.isEmpty
    }
    
    /// Send a message with streaming response
    func sendMessageStreaming(
        conversationId: String?,
        modelId: String,
        messages: [Message],
        onChunk: @escaping @Sendable (String) async -> Void
    ) async throws {
        // Use streaming endpoint (Lambda Function URL)
        guard !AWSConfig.streamingEndpoint.isEmpty else {
            throw APIError.serverError(500, "Streaming endpoint not configured")
        }
        
        let endpoint = URL(string: AWSConfig.streamingEndpoint)!
        
        // Convert messages to DTO format
        let messageDTOs = messages.map { msg in
            MessageDTO(role: msg.role.rawValue, content: msg.content)
        }
        
        let requestBody = ChatRequest(
            conversationId: conversationId,
            modelId: modelId,
            messages: messageDTOs,
            stream: true
        )
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        
        // Add authentication token (validated by Lambda)
        let token = try await getIdToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        request.timeoutInterval = AWSConfig.streamingTimeout
        
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.serverError(httpResponse.statusCode, "Streaming request failed")
        }
        
        // Parse SSE stream
        for try await line in bytes.lines {
            // SSE format: "data: {...}" or "data: [DONE]"
            guard line.hasPrefix("data: ") else { continue }
            
            let jsonString = String(line.dropFirst(6)) // Remove "data: " prefix
            
            if jsonString == "[DONE]" {
                break
            }
            
            guard let jsonData = jsonString.data(using: .utf8) else { continue }
            
            do {
                let chunk = try JSONDecoder().decode(StreamChunk.self, from: jsonData)
                
                // Check for errors
                if let error = chunk.error {
                    throw APIError.serverError(500, error.message)
                }
                
                // Extract content from delta
                if let content = chunk.choices?.first?.delta?.content {
                    await onChunk(content)
                }
                
                // Check if finished
                if chunk.choices?.first?.finishReason != nil {
                    break
                }
            } catch let error as APIError {
                throw error
            } catch {
                // Skip malformed chunks
                continue
            }
        }
    }
    
    // MARK: - Conversations Endpoint
    
    struct ConversationDTO: Codable {
        let id: String
        let title: String
        let modelId: String
        let createdAt: String
        let updatedAt: String
        let messageCount: Int
        var messages: [ConversationMessageDTO]?
    }
    
    struct ConversationMessageDTO: Codable {
        let id: String
        let role: String
        let content: String
        let timestamp: String
        let modelId: String?
        let isError: Bool?
        let errorMessage: String?
    }
    
    struct ConversationsListResponse: Codable {
        let conversations: [ConversationDTO]
    }
    
    struct ConversationResponse: Codable {
        let conversation: ConversationDTO
    }
    
    struct CreateConversationRequest: Codable {
        let title: String?
        let modelId: String
    }
    
    struct UpdateConversationRequest: Codable {
        let title: String?
        let modelId: String?
    }
    
    struct AddMessageRequest: Codable {
        let role: String
        let content: String
        let modelId: String?
        let isError: Bool?
        let errorMessage: String?
    }
    
    struct MessageResponse: Codable {
        let message: ConversationMessageDTO
    }
    
    /// Fetch all conversations for the current user
    func listConversations() async throws -> [ConversationDTO] {
        let endpoint = URL(string: AWSConfig.conversationsEndpoint)!
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        
        let token = try await getIdToken()
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
        
        let listResponse = try JSONDecoder().decode(ConversationsListResponse.self, from: data)
        return listResponse.conversations
    }
    
    /// Create a new conversation
    func createConversation(title: String?, modelId: String) async throws -> ConversationDTO {
        let endpoint = URL(string: AWSConfig.conversationsEndpoint)!
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let token = try await getIdToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let requestBody = CreateConversationRequest(title: title, modelId: modelId)
        request.httpBody = try JSONEncoder().encode(requestBody)
        request.timeoutInterval = AWSConfig.requestTimeout
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }
        
        guard httpResponse.statusCode == 201 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError(httpResponse.statusCode, errorMessage)
        }
        
        let convResponse = try JSONDecoder().decode(ConversationResponse.self, from: data)
        return convResponse.conversation
    }
    
    /// Get a conversation with all its messages
    func getConversation(_ id: String) async throws -> ConversationDTO {
        let endpoint = URL(string: "\(AWSConfig.conversationsEndpoint)/\(id)")!
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        
        let token = try await getIdToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = AWSConfig.requestTimeout
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }
        
        if httpResponse.statusCode == 404 {
            throw APIError.serverError(404, "Conversation not found")
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError(httpResponse.statusCode, errorMessage)
        }
        
        let convResponse = try JSONDecoder().decode(ConversationResponse.self, from: data)
        return convResponse.conversation
    }
    
    /// Update a conversation (title, modelId)
    func updateConversation(_ id: String, title: String? = nil, modelId: String? = nil) async throws -> ConversationDTO {
        let endpoint = URL(string: "\(AWSConfig.conversationsEndpoint)/\(id)")!
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let token = try await getIdToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let requestBody = UpdateConversationRequest(title: title, modelId: modelId)
        request.httpBody = try JSONEncoder().encode(requestBody)
        request.timeoutInterval = AWSConfig.requestTimeout
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }
        
        if httpResponse.statusCode == 404 {
            throw APIError.serverError(404, "Conversation not found")
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError(httpResponse.statusCode, errorMessage)
        }
        
        let convResponse = try JSONDecoder().decode(ConversationResponse.self, from: data)
        return convResponse.conversation
    }
    
    /// Delete a conversation and all its messages
    func deleteConversation(_ id: String) async throws {
        let endpoint = URL(string: "\(AWSConfig.conversationsEndpoint)/\(id)")!
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "DELETE"
        
        let token = try await getIdToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = AWSConfig.requestTimeout
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }
        
        if httpResponse.statusCode == 404 {
            throw APIError.serverError(404, "Conversation not found")
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError(httpResponse.statusCode, errorMessage)
        }
    }
    
    /// Add a message to a conversation
    func addMessage(
        to conversationId: String,
        role: String,
        content: String,
        modelId: String? = nil,
        isError: Bool? = nil,
        errorMessage: String? = nil
    ) async throws -> ConversationMessageDTO {
        let endpoint = URL(string: "\(AWSConfig.conversationsEndpoint)/\(conversationId)/messages")!
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let token = try await getIdToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let requestBody = AddMessageRequest(
            role: role,
            content: content,
            modelId: modelId,
            isError: isError,
            errorMessage: errorMessage
        )
        request.httpBody = try JSONEncoder().encode(requestBody)
        request.timeoutInterval = AWSConfig.requestTimeout
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }
        
        if httpResponse.statusCode == 404 {
            throw APIError.serverError(404, "Conversation not found")
        }
        
        guard httpResponse.statusCode == 201 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError(httpResponse.statusCode, errorMessage)
        }
        
        let msgResponse = try JSONDecoder().decode(MessageResponse.self, from: data)
        return msgResponse.message
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
        let token = try await getIdToken()
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
