//
//  MessageListView.swift
//  ThinkTank
//
//  Created by John Gambrell on 1/29/26.
//

import SwiftUI

struct MessageListView: View {
    let messages: [Message]
    let isLoading: Bool
    var onRetry: ((UUID) -> Void)?
    
    @Environment(ConversationStore.self) private var conversationStore
    @Environment(\.colorScheme) private var colorScheme
    
    private var isStreaming: Bool {
        conversationStore.streamingMessageId != nil
    }
    
    private var streamingContent: String {
        conversationStore.streamingContent
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 24) {
                    ForEach(messages) { message in
                        MessageBubbleView(message: message, onRetry: onRetry)
                            .id(message.id)
                    }
                    
                    // Streaming message view
                    if isStreaming {
                        StreamingMessageView(content: streamingContent)
                            .id("streaming")
                    } else if isLoading {
                        // Show typing indicator only before streaming starts
                        TypingIndicatorView()
                            .id("typing")
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
            }
            .onChange(of: messages.count) { _, _ in
                withAnimation {
                    proxy.scrollTo(messages.last?.id, anchor: .bottom)
                }
            }
            .onChange(of: isLoading) { _, newValue in
                if newValue && !isStreaming {
                    withAnimation {
                        proxy.scrollTo("typing", anchor: .bottom)
                    }
                }
            }
            .onChange(of: streamingContent) { _, _ in
                // Auto-scroll as content streams in
                proxy.scrollTo("streaming", anchor: .bottom)
            }
        }
    }
}

struct StreamingMessageView: View {
    let content: String
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var cursorVisible: Bool = true
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // AI Avatar
            Circle()
                .fill(Color.brandPrimaryLight)
                .frame(width: 32, height: 32)
                .overlay(
                    Text("AI")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.brandPrimary)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                // Streaming content with cursor
                HStack(alignment: .bottom, spacing: 0) {
                    Text(content.isEmpty ? " " : content)
                        .font(.system(size: 14))
                        .foregroundStyle(ThemeColors.primaryText(colorScheme))
                        .textSelection(.enabled)
                    
                    // Blinking cursor
                    Rectangle()
                        .fill(Color.brandPrimary)
                        .frame(width: 2, height: 16)
                        .opacity(cursorVisible ? 1 : 0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(ThemeColors.assistantBubble(colorScheme))
                )
                
                // Streaming indicator
                HStack(spacing: 4) {
                    ProgressView()
                        .controlSize(.mini)
                    Text("Generating...")
                        .font(.system(size: 11))
                        .foregroundStyle(ThemeColors.tertiaryText(colorScheme))
                }
            }
            
            Spacer(minLength: 100)
        }
        .onAppear {
            // Blink cursor
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                cursorVisible.toggle()
            }
        }
    }
}

struct TypingIndicatorView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // AI Avatar
            Circle()
                .fill(Color.brandPrimaryLight)
                .frame(width: 32, height: 32)
                .overlay(
                    Text("AI")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.brandPrimary)
                )
            
            // Typing dots
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(ThemeColors.tertiaryText(colorScheme))
                        .frame(width: 8, height: 8)
                        .offset(y: animationOffset(for: index))
                }
            }
            .padding(.vertical, 12)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            withAnimation(
                Animation.easeInOut(duration: 0.6)
                    .repeatForever(autoreverses: true)
            ) {
                animationOffset = -4
            }
        }
    }
    
    private func animationOffset(for index: Int) -> CGFloat {
        let delay = Double(index) * 0.15
        return animationOffset * cos(delay * .pi)
    }
}

#Preview {
    MessageListView(
        messages: [
            Message(role: .user, content: "Hello, how are you?"),
            Message(role: .assistant, content: "I'm doing great! How can I help you today?", modelId: "anthropic.claude-3-5-sonnet"),
            Message(role: .user, content: "Can you help me with an error?"),
            Message(role: .assistant, content: "Failed to get response", errorMessage: "Server error (504): Endpoint request timed out", isError: true)
        ],
        isLoading: false,
        onRetry: { _ in print("Retry") }
    )
    .environment(ConversationStore())
    .frame(width: 600, height: 400)
}
