//
//  ChatHeaderView.swift
//  ThinkTank
//
//  Created by John Gambrell on 1/29/26.
//

import SwiftUI

struct ChatHeaderView: View {
    @EnvironmentObject var conversationStore: ConversationStore
    @Environment(\.colorScheme) var colorScheme
    
    @Binding var showModelSelector: Bool
    
    var body: some View {
        HStack {
            // Conversation Title
            Text(conversationStore.selectedConversation?.title ?? "New Chat")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(ThemeColors.primaryText(colorScheme))
            
            Spacer()
            
            // Model Selector Button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showModelSelector.toggle()
                }
            }) {
                HStack(spacing: 8) {
                    Text(selectedModelName)
                        .font(.system(size: 12))
                        .foregroundColor(showModelSelector ? Color.brandPrimary : ThemeColors.secondaryText(colorScheme))
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(showModelSelector ? Color.brandPrimary : ThemeColors.tertiaryText(colorScheme))
                        .rotationEffect(.degrees(showModelSelector ? 180 : 0))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(ThemeColors.inputBackground(colorScheme))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(showModelSelector ? Color.brandPrimary : ThemeColors.border(colorScheme), lineWidth: showModelSelector ? 2 : 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .frame(height: 56)
        .background(ThemeColors.cardBackground(colorScheme))
    }
    
    private var selectedModelName: String {
        guard let modelId = conversationStore.selectedConversation?.modelId,
              let model = AIModel.model(for: modelId) else {
            return AIModel.defaultModel.displayName
        }
        return model.displayName
    }
}

#Preview {
    ChatHeaderView(showModelSelector: .constant(false))
        .environmentObject(ConversationStore())
}
