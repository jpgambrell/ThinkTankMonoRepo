//
//  ChatView.swift
//  ThinkTank
//
//  Created by John Gambrell on 1/29/26.
//

import SwiftUI

struct ChatView: View {
    @Environment(ConversationStore.self) private var conversationStore
    @Environment(CognitoAuthService.self) private var authService
    @Environment(SubscriptionService.self) private var subscriptionService
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var messageText: String = ""
    @State private var isLoading: Bool = false
    @State private var showModelSelector: Bool = false
    @State private var retryingMessageId: UUID?
    @State private var showGuestUpgrade: Bool = false
    @State private var showGuestLimitOverlay: Bool = false
    @State private var showPaywall: Bool = false
    
    /// Whether the user can send unlimited messages (Pro subscriber or non-guest)
    private var hasUnlimitedMessages: Bool {
        subscriptionService.isProUser || !authService.isGuestAccount
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                ChatHeaderView(showModelSelector: $showModelSelector)
                
                Divider()
                    .background(ThemeColors.divider(colorScheme))
                
                // Free Tier Message Banner (shown for all non-Pro users)
                if !subscriptionService.isProUser {
                    GuestMessageBanner(
                        remainingMessages: authService.remainingFreeMessages,
                        maxMessages: authService.maxAllowedFreeMessages,
                        onUpgrade: { 
                            if authService.isGuestAccount {
                                showGuestUpgrade = true
                            } else {
                                showPaywall = true
                            }
                        },
                        buttonText: authService.isGuestAccount ? "Create Account" : "Upgrade"
                    )
                }
                
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
            
            // Guest Limit Reached Overlay
            if showGuestLimitOverlay {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                
                GuestLimitReachedOverlay(
                    onUpgrade: {
                        showGuestLimitOverlay = false
                        if authService.isGuestAccount {
                            showGuestUpgrade = true
                        } else {
                            showPaywall = true
                        }
                    },
                    onSignOut: {
                        showGuestLimitOverlay = false
                        authService.signOut()
                    },
                    isGuestAccount: authService.isGuestAccount
                )
            }
        }
        .overlay {
            if showGuestUpgrade {
                GuestUpgradeView(isPresented: $showGuestUpgrade)
                    .environment(authService)
                    .environment(subscriptionService)
                    .transition(.opacity)
            }
        }
        .overlay {
            if showPaywall {
                SubscriptionPaywallView(isPresented: $showPaywall, showSkipButton: true)
                    .environment(subscriptionService)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showGuestUpgrade)
        .animation(.easeInOut(duration: 0.2), value: showPaywall)
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Pro subscribers always have unlimited messages
        // Non-Pro users have message limits
        if !subscriptionService.isProUser && authService.freeMessageCount >= authService.maxAllowedFreeMessages {
            showGuestLimitOverlay = true
            return
        }
        
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
        
        // Increment free message count for non-Pro users
        if !subscriptionService.isProUser {
            authService.incrementFreeMessageCount()
        }
        
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
        .environment(CognitoAuthService.shared)
        .environment(SubscriptionService())
}
