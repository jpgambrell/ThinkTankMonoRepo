//
//  ChatView.swift
//  ThinkTank
//
//  Created by John Gambrell on 1/29/26.
//

import SwiftUI

struct ChatView: View {
    @Environment(ConversationStore.self) private var conversationStore
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var messageText: String = ""
    @State private var isLoading: Bool = false
    @State private var showModelSelector: Bool = false
    @State private var retryingMessageId: UUID?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            ChatHeaderView(showModelSelector: $showModelSelector)
            
            Divider()
                .background(ThemeColors.divider(colorScheme))
            
            // Messages or Empty State
            if let conversation = conversationStore.selectedConversation {
                if conversation.messages.isEmpty {
                    EmptyStateView()
                } else {
                    MessageListView(
                        messages: conversation.messages,
                        isLoading: isLoading,
                        onRetry: retryMessage
                    )
                }
            } else {
                EmptyStateView()
            }
            
            Divider()
                .background(ThemeColors.divider(colorScheme))
            
            // Input Area
            ChatInputView(
                messageText: $messageText,
                isLoading: isLoading,
                onSend: sendMessage
            )
        }
        .background(ThemeColors.cardBackground(colorScheme))
        .overlay(alignment: .topTrailing) {
            if showModelSelector {
                ModelSelectorView(isPresented: $showModelSelector)
                    .offset(x: -20, y: 50)
            }
        }
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Auto-create a new conversation if none exists
        let conversation: Conversation
        if let existing = conversationStore.selectedConversation {
            conversation = existing
        } else {
            conversation = conversationStore.createNewConversation()
        }
        
        let userMessage = Message(
            role: .user,
            content: messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        
        // Add user message
        conversationStore.addMessage(to: conversation.id, message: userMessage)
        messageText = ""
        
        // Send to AI
        sendToAI(conversationId: conversation.id, userMessage: userMessage)
    }
    
    private func retryMessage(errorMessageId: UUID) {
        guard let conversation = conversationStore.selectedConversation else { return }
        
        // Find the user message before this error message
        guard let errorIndex = conversation.messages.firstIndex(where: { $0.id == errorMessageId }),
              errorIndex > 0 else { return }
        
        let userMessage = conversation.messages[errorIndex - 1]
        guard userMessage.role == .user else { return }
        
        // Remove the error message
        conversationStore.removeMessage(from: conversation.id, messageId: errorMessageId)
        
        // Retry sending
        sendToAI(conversationId: conversation.id, userMessage: userMessage)
    }
    
    private func sendToAI(conversationId: UUID, userMessage: Message) {
        isLoading = true
        
        Task {
            do {
                // Use streaming if available, otherwise fall back to non-streaming
                if AWSConfig.streamingEndpoint.isEmpty {
                    // Non-streaming mode
                    let response = try await conversationStore.sendMessage(
                        conversationId: conversationId,
                        userMessage: userMessage
                    )
                    
                    await MainActor.run {
                        conversationStore.addMessage(to: conversationId, message: response)
                        isLoading = false
                    }
                } else {
                    // Streaming mode
                    let response = try await conversationStore.sendMessageStreaming(
                        conversationId: conversationId,
                        userMessage: userMessage
                    )
                    
                    await MainActor.run {
                        conversationStore.addMessage(to: conversationId, message: response)
                        isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    let errorMessage = Message.errorMessage(for: error)
                    conversationStore.addMessage(to: conversationId, message: errorMessage)
                    isLoading = false
                    print("Error: \(error.localizedDescription)")
                }
            }
        }
    }
}

#Preview {
    ChatView()
        .frame(width: 800, height: 600)
        .environment(ConversationStore())
        .environment(ThemeManager())
}
