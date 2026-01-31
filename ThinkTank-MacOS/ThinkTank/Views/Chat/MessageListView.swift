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
    // Core state: is auto-scroll paused by user interaction?
    @State private var isAutoScrollPaused: Bool = false
    // Is user currently dragging the scroll view?
    @State private var isUserDragging: Bool = false
    // Is the scroll position near the bottom?
    @State private var isNearBottom: Bool = true
    // Reference to scroll proxy for programmatic scrolling
    @State private var scrollProxy: ScrollViewProxy?
    // Task for debouncing streaming scroll updates
    @State private var scrollTask: Task<Void, Never>?
    // Track previous message count to detect new user messages
    @State private var previousMessageCount: Int = 0
    
    private var isStreaming: Bool {
        conversationStore.streamingMessageId != nil
    }
    
    private var streamingContent: String {
        conversationStore.streamingContent
    }
    
    // Show follow button when auto-scroll is paused during active content generation
    private var showScrollToBottomButton: Bool {
        isAutoScrollPaused && (isStreaming || isLoading)
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
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
                // Detect user-initiated scrolling via drag gesture
                // Using simultaneousGesture allows ScrollView to still function normally
                .simultaneousGesture(
                    DragGesture(minimumDistance: 5)
                        .onChanged { _ in
                            // Mark that user is actively dragging
                            isUserDragging = true
                            // Pause auto-scroll only during active content generation
                            if isStreaming || isLoading {
                                isAutoScrollPaused = true
                            }
                        }
                        .onEnded { _ in
                            // User stopped dragging
                            isUserDragging = false
                            // If user dragged to bottom, resume auto-scroll
                            if isNearBottom && isAutoScrollPaused {
                                isAutoScrollPaused = false
                            }
                        }
                )
                // Track scroll position to know if we're at bottom
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    let visibleHeight = geometry.visibleRect.height
                    let contentHeight = geometry.contentSize.height
                    let scrollOffset = geometry.contentOffset.y
                    let distanceFromBottom = contentHeight - (scrollOffset + visibleHeight)
                    return distanceFromBottom < 50
                } action: { _, nowAtBottom in
                    isNearBottom = nowAtBottom
                    
                    // If user manually scrolled to bottom (drag ended at bottom), resume auto-scroll
                    // We check !isUserDragging because onEnded may fire slightly before this
                    if nowAtBottom && isAutoScrollPaused && !isUserDragging {
                        // Small delay to ensure drag gesture has fully ended
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(50))
                            if isNearBottom && !isUserDragging {
                                isAutoScrollPaused = false
                            }
                        }
                    }
                }
                .onAppear {
                    scrollProxy = proxy
                    previousMessageCount = messages.count
                }
                .onChange(of: isStreaming) { oldValue, newValue in
                    // When streaming STARTS: reset pause state and scroll to follow
                    if newValue && !oldValue {
                        isAutoScrollPaused = false
                        scrollToBottom(proxy: proxy, animated: true, anchorId: "streaming")
                    }
                    // When streaming ENDS: if still paused, keep paused (user's choice)
                    // No action needed
                }
                .onChange(of: messages.count) { oldCount, newCount in
                    // Detect if a new user message was added (user sent a message)
                    // User messages mean user wants to see the response
                    if newCount > oldCount {
                        if let lastMessage = messages.last, lastMessage.role == .user {
                            // User just sent a message - resume auto-scroll
                            isAutoScrollPaused = false
                            scrollToBottom(proxy: proxy, animated: true)
                        } else if !isAutoScrollPaused {
                            // New assistant message and not paused - scroll to it
                            scrollToBottom(proxy: proxy, animated: true)
                        }
                    }
                    previousMessageCount = newCount
                }
                .onChange(of: isLoading) { _, newValue in
                    // When loading starts (typing indicator), scroll to show it
                    if newValue && !isStreaming && !isAutoScrollPaused {
                        scrollToBottom(proxy: proxy, animated: true, anchorId: "typing")
                    }
                }
                .onChange(of: streamingContent) { _, _ in
                    // Content is streaming in - scroll if not paused
                    if !isAutoScrollPaused {
                        scheduleStreamingScroll(proxy: proxy)
                    }
                }
            }
            
            // Floating "Follow" button - appears when user has paused auto-scroll
            if showScrollToBottomButton {
                ScrollToBottomButton {
                    resumeAutoScroll()
                }
                .padding(.bottom, 16)
                .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showScrollToBottomButton)
    }
    
    // MARK: - Private Methods
    
    /// Resume auto-scrolling and immediately scroll to current content
    private func resumeAutoScroll() {
        isAutoScrollPaused = false
        isNearBottom = true
        
        if let proxy = scrollProxy {
            scrollToBottom(proxy: proxy, animated: true, anchorId: currentScrollAnchor())
            // Also schedule an immediate streaming scroll update
            scheduleStreamingScroll(proxy: proxy)
        }
    }
    
    /// Debounced scroll during streaming to avoid excessive scroll calls
    private func scheduleStreamingScroll(proxy: ScrollViewProxy) {
        scrollTask?.cancel()
        scrollTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            guard !Task.isCancelled, !isAutoScrollPaused else { return }
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

// Floating button to scroll to bottom and resume auto-scroll
struct ScrollToBottomButton: View {
    let action: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered: Bool = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 12, weight: .semibold))
                Text("Follow")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.brandPrimary)
                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            )
            .scaleEffect(isHovered ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
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
