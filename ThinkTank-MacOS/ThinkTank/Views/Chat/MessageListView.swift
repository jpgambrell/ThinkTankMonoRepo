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
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 24) {
                    ForEach(messages) { message in
                        MessageBubbleView(message: message)
                            .id(message.id)
                    }
                    
                    // Loading indicator
                    if isLoading {
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
                if newValue {
                    withAnimation {
                        proxy.scrollTo("typing", anchor: .bottom)
                    }
                }
            }
        }
    }
}

struct TypingIndicatorView: View {
    @Environment(\.colorScheme) var colorScheme
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
                        .foregroundColor(Color.brandPrimary)
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
            Message(role: .assistant, content: "I'm doing great! How can I help you today?", modelId: "anthropic.claude-3-5-sonnet")
        ],
        isLoading: true
    )
    .frame(width: 600, height: 400)
}
