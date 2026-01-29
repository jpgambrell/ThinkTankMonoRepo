//
//  ChatView.swift
//  ThinkTank
//
//  Created by John Gambrell on 1/29/26.
//

import SwiftUI

struct ChatView: View {
    @EnvironmentObject var conversationStore: ConversationStore
    @Environment(\.colorScheme) var colorScheme
    
    @State private var messageText: String = ""
    @State private var isLoading: Bool = false
    @State private var showModelSelector: Bool = false
    
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
                        isLoading: isLoading
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
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let conversation = conversationStore.selectedConversation else { return }
        
        let userMessage = Message(
            role: .user,
            content: messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        
        // Add user message
        conversationStore.addMessage(to: conversation.id, message: userMessage)
        messageText = ""
        isLoading = true
        
        // Get AI response
        Task {
            do {
                let response = try await conversationStore.sendMessage(
                    conversationId: conversation.id,
                    userMessage: userMessage
                )
                
                await MainActor.run {
                    conversationStore.addMessage(to: conversation.id, message: response)
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    // TODO: Show error alert to user
                    print("Error: \(error.localizedDescription)")
                }
            }
        }
    }
}

#Preview {
    ChatView()
        .frame(width: 800, height: 600)
        .environmentObject(ConversationStore())
        .environmentObject(ThemeManager())
}
