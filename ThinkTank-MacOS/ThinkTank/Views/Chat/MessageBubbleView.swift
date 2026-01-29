//
//  MessageBubbleView.swift
//  ThinkTank
//
//  Created by John Gambrell on 1/29/26.
//

import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovered: Bool = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.role == .user {
                Spacer(minLength: 100)
                userMessage
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
                .foregroundColor(.white)
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
                        .foregroundColor(ThemeColors.tertiaryText(colorScheme))
                    
                    Button(action: copyToClipboard) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 11))
                            .foregroundColor(ThemeColors.tertiaryText(colorScheme))
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
                        .foregroundColor(Color.brandPrimary)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(message.content)
                    .font(.system(size: 14))
                    .foregroundColor(ThemeColors.primaryText(colorScheme))
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
                                .foregroundColor(ThemeColors.tertiaryText(colorScheme))
                            
                            Text("•")
                                .font(.system(size: 11))
                                .foregroundColor(ThemeColors.tertiaryText(colorScheme))
                        }
                        
                        Text(formattedTime)
                            .font(.system(size: 11))
                            .foregroundColor(ThemeColors.tertiaryText(colorScheme))
                        
                        Button(action: copyToClipboard) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 11))
                                .foregroundColor(ThemeColors.tertiaryText(colorScheme))
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
    }
    .padding()
    .frame(width: 600)
}
