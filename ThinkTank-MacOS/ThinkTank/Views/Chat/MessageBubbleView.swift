//
//  MessageBubbleView.swift
//  ThinkTank
//
//  Created by John Gambrell on 1/29/26.
//

import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    var onRetry: ((UUID) -> Void)?
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered: Bool = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.role == .user {
                Spacer(minLength: 100)
                userMessage
            } else if message.isError {
                errorMessage
                Spacer(minLength: 100)
            } else {
                assistantMessage
                Spacer(minLength: 100)
            }
        }
    }
    
    private var userMessage: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(message.content)
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .textSelection(.enabled)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.brandPrimary)
                )
            
            if isHovered {
                HStack(spacing: 8) {
                    Text(formattedTime)
                        .font(.system(size: 11))
                        .foregroundStyle(ThemeColors.tertiaryText(colorScheme))
                    
                    Button(action: copyToClipboard) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 11))
                            .foregroundStyle(ThemeColors.tertiaryText(colorScheme))
                    }
                    .buttonStyle(.plain)
                }
                .transition(.opacity)
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
    
    private var assistantMessage: some View {
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
                Text(message.content)
                    .font(.system(size: 14))
                    .foregroundStyle(ThemeColors.primaryText(colorScheme))
                    .textSelection(.enabled)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(ThemeColors.assistantBubble(colorScheme))
                    )
                
                if isHovered {
                    HStack(spacing: 8) {
                        if let modelId = message.modelId,
                           let model = AIModel.model(for: modelId) {
                            Text(model.displayName)
                                .font(.system(size: 11))
                                .foregroundStyle(ThemeColors.tertiaryText(colorScheme))
                            
                            Text("•")
                                .font(.system(size: 11))
                                .foregroundStyle(ThemeColors.tertiaryText(colorScheme))
                        }
                        
                        Text(formattedTime)
                            .font(.system(size: 11))
                            .foregroundStyle(ThemeColors.tertiaryText(colorScheme))
                        
                        Button(action: copyToClipboard) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 11))
                                .foregroundStyle(ThemeColors.tertiaryText(colorScheme))
                        }
                        .buttonStyle(.plain)
                    }
                    .transition(.opacity)
                }
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
    
    private var errorMessage: some View {
        HStack(alignment: .top, spacing: 12) {
            // Error Icon
            Circle()
                .fill(Color.destructive.opacity(0.15))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.destructive)
                )
            
            VStack(alignment: .leading, spacing: 8) {
                // Error content
                VStack(alignment: .leading, spacing: 6) {
                    Text(message.content)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.destructive)
                    
                    if let errorDetail = message.errorMessage {
                        Text(errorDetail)
                            .font(.system(size: 13))
                            .foregroundStyle(ThemeColors.secondaryText(colorScheme))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.destructive.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.destructive.opacity(0.3), lineWidth: 1)
                )
                
                // Retry button
                Button {
                    onRetry?(message.id)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .medium))
                        Text("Retry")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(Color.brandPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.brandPrimary, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: message.timestamp)
    }
    
    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(message.content, forType: .string)
    }
}

#Preview {
    VStack(spacing: 16) {
        MessageBubbleView(
            message: Message(
                role: .user,
                content: "Hello, can you help me with Swift programming?"
            )
        )
        
        MessageBubbleView(
            message: Message(
                role: .assistant,
                content: "Of course! I'd be happy to help you with Swift programming. What would you like to know?",
                modelId: "anthropic.claude-3-5-sonnet"
            )
        )
        
        MessageBubbleView(
            message: Message(
                role: .assistant,
                content: "Failed to get response",
                errorMessage: "Server error (504): Endpoint request timed out",
                isError: true
            ),
            onRetry: { _ in print("Retry tapped") }
        )
    }
    .padding()
    .frame(width: 600)
}
