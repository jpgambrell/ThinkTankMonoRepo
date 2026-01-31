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
    
    // MARK: - Scroll State
    // When true, we stop auto-scrolling and let user read freely
    @State private var userTookControl: Bool = false
    @State private var scrollTask: Task<Void, Never>?
    
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
                    
                    // Invisible anchor at the very bottom
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
            }
            // Detect when user scrolls - they're taking control
            .onScrollPhaseChange { oldPhase, newPhase in
                // User started interacting with scroll
                if newPhase == .interacting {
                    userTookControl = true
                }
            }
            // Track when user scrolls to bottom to give control back
            .onScrollGeometryChange(for: Bool.self) { geometry in
                let visibleHeight = geometry.visibleRect.height
                let contentHeight = geometry.contentSize.height
                let scrollOffset = geometry.contentOffset.y
                let distanceFromBottom = contentHeight - (scrollOffset + visibleHeight)
                // Very close to bottom (within 20px)
                return distanceFromBottom < 20
            } action: { _, isAtBottom in
                // Only resume auto-scroll if user scrolled all the way to bottom
                if isAtBottom && userTookControl {
                    userTookControl = false
                }
            }
            .onChange(of: isStreaming) { oldValue, newValue in
                // When streaming STARTS: scroll to the streaming message
                if newValue && !oldValue {
                    userTookControl = false
                    scrollToBottom(proxy: proxy, animated: true, anchorId: "streaming")
                }
            }
            .onChange(of: messages.count) { oldCount, newCount in
                // New message added
                if newCount > oldCount {
                    if let lastMessage = messages.last, lastMessage.role == .user {
                        // User sent a message - they want to see the response
                        userTookControl = false
                        scrollToBottom(proxy: proxy, animated: true)
                    } else if !userTookControl {
                        // New assistant message and user hasn't taken control
                        scrollToBottom(proxy: proxy, animated: true)
                    }
                }
            }
            .onChange(of: isLoading) { _, newValue in
                // When loading starts, scroll to show typing indicator (if user hasn't taken control)
                if newValue && !isStreaming && !userTookControl {
                    scrollToBottom(proxy: proxy, animated: true, anchorId: "typing")
                }
            }
            .onChange(of: streamingContent) { _, _ in
                // Content is streaming in - only scroll if user hasn't taken control
                if !userTookControl {
                    scheduleStreamingScroll(proxy: proxy)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Debounced scroll during streaming to avoid excessive scroll calls
    private func scheduleStreamingScroll(proxy: ScrollViewProxy) {
        scrollTask?.cancel()
        scrollTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            guard !Task.isCancelled, !userTookControl else { return }
            scrollToBottom(proxy: proxy, animated: false, anchorId: currentScrollAnchor())
        }
    }
    
    /// Determine the current scroll anchor based on content state
    private func currentScrollAnchor() -> String {
        if isStreaming {
            return "streaming"
        }
        if isLoading {
            return "typing"
        }
        return "bottom"
    }
    
    /// Scroll to the specified anchor
    private func scrollToBottom(
        proxy: ScrollViewProxy?,
        animated: Bool,
        anchorId: String = "bottom"
    ) {
        guard let proxy else { return }
        
        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(anchorId, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(anchorId, anchor: .bottom)
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
