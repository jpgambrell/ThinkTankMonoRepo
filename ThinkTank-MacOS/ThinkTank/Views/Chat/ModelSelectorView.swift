//
//  ModelSelectorView.swift
//  ThinkTank
//
//  Created by John Gambrell on 1/29/26.
//

import SwiftUI

struct ModelSelectorView: View {
    @Environment(ConversationStore.self) private var conversationStore
    @Environment(\.colorScheme) private var colorScheme
    
    @Binding var isPresented: Bool
    
    private var selectedModelId: String {
        conversationStore.selectedConversation?.modelId ?? AIModel.defaultModel.id
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(AIModel.modelsByProvider.keys.sorted()), id: \.self) { provider in
                if let models = AIModel.modelsByProvider[provider] {
                    // Provider Header
                    Text(provider.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ThemeColors.tertiaryText(colorScheme))
                        .tracking(0.5)
                        .padding(.horizontal, 12)
                        .padding(.top, provider == AIModel.modelsByProvider.keys.sorted().first ? 8 : 12)
                    
                    // Models
                    ForEach(models) { model in
                        ModelRowView(
                            model: model,
                            isSelected: model.id == selectedModelId,
                            onSelect: {
                                selectModel(model)
                            }
                        )
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .frame(width: 240)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ThemeColors.cardBackground(colorScheme))
                .shadow(color: Color.black.opacity(0.15), radius: 16, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ThemeColors.border(colorScheme), lineWidth: 1)
        )
    }
    
    private func selectModel(_ model: AIModel) {
        // Save as the default model for future chats
        AIModel.setDefaultModel(model)
        
        if let conversationId = conversationStore.selectedConversationId {
            // Update existing conversation's model
            conversationStore.updateConversationModel(conversationId, modelId: model.id)
        } else {
            // Create a new conversation with the selected model
            _ = conversationStore.createNewConversation(modelId: model.id)
        }
        withAnimation {
            isPresented = false
        }
    }
}

struct ModelRowView: View {
    let model: AIModel
    let isSelected: Bool
    let onSelect: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered: Bool = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Provider Icon
                Circle()
                    .fill(model.providerColor)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Text(model.iconLetter)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    )
                
                // Model Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(ThemeColors.primaryText(colorScheme))
                    
                    Text(model.description)
                        .font(.system(size: 11))
                        .foregroundStyle(ThemeColors.tertiaryText(colorScheme))
                }
                
                Spacer()
                
                // Checkmark for selected
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.brandPrimary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundColor)
            )
            .padding(.horizontal, 8)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Color.brandPrimaryLight
        } else if isHovered {
            return ThemeColors.hoverBackground(colorScheme)
        } else {
            return .clear
        }
    }
}

#Preview {
    ModelSelectorView(isPresented: .constant(true))
        .environment(ConversationStore())
        .padding()
        .background(Color.gray.opacity(0.2))
}
