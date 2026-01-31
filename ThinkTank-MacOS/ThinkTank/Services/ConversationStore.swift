//
//  ConversationStore.swift
//  ThinkTank
//
//  Created by John Gambrell on 1/29/26.
//

import Foundation
import SwiftUI
import Observation

@Observable
@MainActor
final class ConversationStore {
    var conversations: [Conversation] = []
    var selectedConversationId: UUID?
    var isLoading: Bool = false
    
    // Streaming state
    var streamingMessageId: UUID?
    var streamingContent: String = ""
    
    private let apiClient = APIClient()
    
    var selectedConversation: Conversation? {
        guard let id = selectedConversationId else { return nil }
        return conversations.first { $0.id == id }
    }
    
    init() {
        // Start with empty conversations
        // User can create new conversations after sign in
    }
    
    // MARK: - Mock Data
    private func loadMockData() {
        let now = Date()
        let calendar = Calendar.current
        
        // Today's conversations
        let conv1 = Conversation(
            title: "macOS App PRD Discussion",
            messages: [
                Message(
                    role: .user,
                    content: "I'm writing a prompt to develop a macOS app for AI chatbot. Can you help me create a PRD?",
                    timestamp: calendar.date(byAdding: .minute, value: -10, to: now)!
                ),
                Message(
                    role: .assistant,
                    content: "I'd be happy to help you create a comprehensive PRD for your macOS AI chatbot app. Let me structure this with:\n\n• Core layout specifications\n• Functional requirements\n• Technical architecture",
                    timestamp: calendar.date(byAdding: .minute, value: -9, to: now)!,
                    modelId: "anthropic.claude-3-5-sonnet"
                ),
                Message(
                    role: .user,
                    content: "Yes, and I'll be using AWS Bedrock for the LLM APIs.",
                    timestamp: calendar.date(byAdding: .minute, value: -5, to: now)!
                ),
                Message(
                    role: .assistant,
                    content: "Great choice! AWS Bedrock provides access to multiple foundation models. I'll update the PRD to include:\n\n• Cognito for authentication\n• Lambda + API Gateway microservice layer\n• Bedrock model integration",
                    timestamp: calendar.date(byAdding: .minute, value: -4, to: now)!,
                    modelId: "anthropic.claude-3-5-sonnet"
                )
            ],
            modelId: "anthropic.claude-3-5-sonnet",
            createdAt: calendar.date(byAdding: .minute, value: -10, to: now)!,
            updatedAt: calendar.date(byAdding: .minute, value: -2, to: now)!
        )
        
        let conv2 = Conversation(
            title: "Swift async/await patterns",
            messages: [
                Message(
                    role: .user,
                    content: "What are the best practices for using async/await in Swift?",
                    timestamp: calendar.date(byAdding: .hour, value: -1, to: now)!
                ),
                Message(
                    role: .assistant,
                    content: "Here are the key best practices for async/await in Swift:\n\n1. Use `Task` for creating async contexts from sync code\n2. Prefer `async let` for concurrent operations\n3. Use `TaskGroup` for dynamic concurrency\n4. Always handle cancellation properly",
                    timestamp: calendar.date(byAdding: .hour, value: -1, to: now)!,
                    modelId: "anthropic.claude-3-opus"
                )
            ],
            modelId: "anthropic.claude-3-opus",
            createdAt: calendar.date(byAdding: .hour, value: -1, to: now)!,
            updatedAt: calendar.date(byAdding: .hour, value: -1, to: now)!
        )
        
        let conv3 = Conversation(
            title: "AWS Lambda best practices",
            messages: [
                Message(
                    role: .user,
                    content: "How should I structure my Lambda functions for a REST API?",
                    timestamp: calendar.date(byAdding: .hour, value: -3, to: now)!
                ),
                Message(
                    role: .assistant,
                    content: "For Lambda-based REST APIs, I recommend:\n\n• Single-purpose functions over monolithic handlers\n• Use API Gateway request/response mapping\n• Implement proper error handling\n• Keep cold start times low",
                    timestamp: calendar.date(byAdding: .hour, value: -3, to: now)!,
                    modelId: "anthropic.claude-3-5-sonnet"
                )
            ],
            modelId: "anthropic.claude-3-5-sonnet",
            createdAt: calendar.date(byAdding: .hour, value: -3, to: now)!,
            updatedAt: calendar.date(byAdding: .hour, value: -3, to: now)!
        )
        
        // Yesterday's conversations
        let conv4 = Conversation(
            title: "Cognito integration help",
            messages: [
                Message(
                    role: .user,
                    content: "How do I integrate AWS Cognito with a Swift macOS app?",
                    timestamp: calendar.date(byAdding: .day, value: -1, to: now)!
                ),
                Message(
                    role: .assistant,
                    content: "For Cognito integration in macOS Swift apps:\n\n1. Use AWS Amplify Swift SDK\n2. Configure your User Pool\n3. Implement sign-in/sign-up flows\n4. Store tokens securely in Keychain",
                    timestamp: calendar.date(byAdding: .day, value: -1, to: now)!,
                    modelId: "anthropic.claude-3-5-sonnet"
                )
            ],
            modelId: "anthropic.claude-3-5-sonnet",
            createdAt: calendar.date(byAdding: .day, value: -1, to: now)!,
            updatedAt: calendar.date(byAdding: .day, value: -1, to: now)!
        )
        
        let conv5 = Conversation(
            title: "SwiftUI layout questions",
            messages: [
                Message(
                    role: .user,
                    content: "What's the best way to create a two-panel layout in SwiftUI for macOS?",
                    timestamp: calendar.date(byAdding: .day, value: -1, to: now)!
                ),
                Message(
                    role: .assistant,
                    content: "For a two-panel layout in macOS SwiftUI:\n\n```swift\nNavigationSplitView {\n    // Sidebar content\n} detail: {\n    // Detail content\n}\n```\n\nOr use HSplitView for a resizable split.",
                    timestamp: calendar.date(byAdding: .day, value: -1, to: now)!,
                    modelId: "anthropic.claude-3-opus"
                )
            ],
            modelId: "anthropic.claude-3-opus",
            createdAt: calendar.date(byAdding: .day, value: -1, to: now)!,
            updatedAt: calendar.date(byAdding: .day, value: -1, to: now)!
        )
        
        conversations = [conv1, conv2, conv3, conv4, conv5]
        selectedConversationId = conv1.id
    }
    
    // MARK: - Conversation Management
    
    func createNewConversation(modelId: String? = nil) -> Conversation {
        let conversation = Conversation(modelId: modelId ?? AIModel.defaultModel.id)
        conversations.insert(conversation, at: 0)
        selectedConversationId = conversation.id
        return conversation
    }
    
    func selectConversation(_ conversation: Conversation) {
        selectedConversationId = conversation.id
    }
    
    func deleteConversation(_ conversation: Conversation) {
        conversations.removeAll { $0.id == conversation.id }
        if selectedConversationId == conversation.id {
            selectedConversationId = conversations.first?.id
        }
    }
    
    func renameConversation(_ conversation: Conversation, newTitle: String) {
        guard let index = conversations.firstIndex(where: { $0.id == conversation.id }) else { return }
        conversations[index].title = newTitle
        conversations[index].updatedAt = Date()
    }
    
    func duplicateConversation(_ conversation: Conversation) {
        var newConversation = conversation
        newConversation = Conversation(
            title: "\(conversation.title) (Copy)",
            messages: conversation.messages,
            modelId: conversation.modelId,
            createdAt: Date(),
            updatedAt: Date()
        )
        conversations.insert(newConversation, at: 0)
        selectedConversationId = newConversation.id
    }
    
    func updateConversationModel(_ conversationId: UUID, modelId: String) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationId }) else { return }
        
        print("🔄 Updating conversation model: \(conversations[index].modelId) -> \(modelId)")
        
        // Update the conversation - @Observable automatically tracks changes
        var updatedConversation = conversations[index]
        updatedConversation.modelId = modelId
        updatedConversation.updatedAt = Date()
        conversations[index] = updatedConversation
        
        print("✅ Model updated to: \(conversations[index].modelId)")
    }
    
    // MARK: - Message Management
    
    func addMessage(to conversationId: UUID, message: Message) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationId }) else { return }
        conversations[index].messages.append(message)
        conversations[index].updatedAt = Date()
        
        // Update title if this is the first user message
        if conversations[index].messages.filter({ $0.role == .user }).count == 1,
           message.role == .user {
            // Generate title from first message
            let title = generateTitle(from: message.content)
            conversations[index].title = title
        }
        
        // Move conversation to top
        let conversation = conversations.remove(at: index)
        conversations.insert(conversation, at: 0)
    }
    
    func removeMessage(from conversationId: UUID, messageId: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationId }) else { return }
        conversations[index].messages.removeAll { $0.id == messageId }
        conversations[index].updatedAt = Date()
    }
    
    /// Send a message to the AI and get a response (non-streaming)
    func sendMessage(conversationId: UUID, userMessage: Message) async throws -> Message {
        guard let conversation = conversations.first(where: { $0.id == conversationId }) else {
            throw NSError(domain: "ConversationStore", code: 404, userInfo: [NSLocalizedDescriptionKey: "Conversation not found"])
        }
        
        print("📤 Sending message with model: \(conversation.modelId)")
        
        // Get all messages including the new user message
        var allMessages = conversation.messages
        allMessages.append(userMessage)
        
        // Call the API
        let response = try await apiClient.sendMessage(
            conversationId: conversationId.uuidString,
            modelId: conversation.modelId,
            messages: allMessages
        )
        
        return response
    }
    
    /// Send a message with streaming response
    func sendMessageStreaming(conversationId: UUID, userMessage: Message) async throws -> Message {
        guard let conversation = conversations.first(where: { $0.id == conversationId }) else {
            throw NSError(domain: "ConversationStore", code: 404, userInfo: [NSLocalizedDescriptionKey: "Conversation not found"])
        }
        
        print("📤 Sending streaming message with model: \(conversation.modelId)")
        
        // Get all messages including the new user message
        var allMessages = conversation.messages
        allMessages.append(userMessage)
        
        // Create a placeholder message for streaming
        let messageId = UUID()
        streamingMessageId = messageId
        streamingContent = ""
        
        let modelId = conversation.modelId
        
        do {
            try await apiClient.sendMessageStreaming(
                conversationId: conversationId.uuidString,
                modelId: modelId,
                messages: allMessages
            ) { [weak self] chunk in
                await MainActor.run {
                    self?.streamingContent += chunk
                }
            }
            
            // Create final message from accumulated content
            let finalMessage = Message(
                id: messageId,
                role: .assistant,
                content: streamingContent,
                timestamp: Date(),
                modelId: modelId
            )
            
            // Clear streaming state
            streamingMessageId = nil
            
            return finalMessage
        } catch {
            // Clear streaming state on error
            streamingMessageId = nil
            streamingContent = ""
            throw error
        }
    }
    
    private func generateTitle(from content: String) -> String {
        // Take first line or first 50 chars
        let firstLine = content.split(separator: "\n").first.map(String.init) ?? content
        if firstLine.count > 40 {
            return String(firstLine.prefix(40)) + "..."
        }
        return firstLine
    }
    
    // MARK: - Filtering
    
    func filteredConversations(searchText: String) -> [Conversation] {
        if searchText.isEmpty {
            return conversations
        }
        return conversations.filter { conversation in
            conversation.title.localizedCaseInsensitiveContains(searchText) ||
            conversation.messages.contains { $0.content.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    func conversationsGroupedByDate(searchText: String = "") -> [(String, [Conversation])] {
        let filtered = filteredConversations(searchText: searchText)
        let calendar = Calendar.current
        let now = Date()
        
        var today: [Conversation] = []
        var yesterday: [Conversation] = []
        var thisWeek: [Conversation] = []
        var older: [Conversation] = []
        
        for conversation in filtered {
            if calendar.isDateInToday(conversation.updatedAt) {
                today.append(conversation)
            } else if calendar.isDateInYesterday(conversation.updatedAt) {
                yesterday.append(conversation)
            } else if let weekAgo = calendar.date(byAdding: .day, value: -7, to: now),
                      conversation.updatedAt > weekAgo {
                thisWeek.append(conversation)
            } else {
                older.append(conversation)
            }
        }
        
        var result: [(String, [Conversation])] = []
        if !today.isEmpty { result.append(("TODAY", today)) }
        if !yesterday.isEmpty { result.append(("YESTERDAY", yesterday)) }
        if !thisWeek.isEmpty { result.append(("THIS WEEK", thisWeek)) }
        if !older.isEmpty { result.append(("OLDER", older)) }
        
        return result
    }
}
