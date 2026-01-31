//
//  ConversationRowView.swift
//  ThinkTank
//
//  Created by John Gambrell on 1/29/26.
//

import SwiftUI

struct ConversationRowView: View {
    @Environment(ConversationStore.self) private var conversationStore
    @Environment(\.colorScheme) private var colorScheme
    
    let conversation: Conversation
    let isSelected: Bool
    
    @State private var isHovered: Bool = false
    @State private var isRenaming: Bool = false
    @State private var editedTitle: String = ""
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                if isRenaming {
                    TextField("Conversation name", text: $editedTitle, onCommit: {
                        if !editedTitle.isEmpty {
                            conversationStore.renameConversation(conversation, newTitle: editedTitle)
                        }
                        isRenaming = false
                    })
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(ThemeColors.primaryText(colorScheme))
                } else {
                    Text(conversation.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(isSelected ? ThemeColors.primaryText(colorScheme) : ThemeColors.secondaryText(colorScheme))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                
                HStack(spacing: 4) {
                    Text(modelDisplayName)
                        .font(.system(size: 12))
                        .foregroundStyle(ThemeColors.tertiaryText(colorScheme))
                    
                    Text("•")
                        .font(.system(size: 12))
                        .foregroundStyle(ThemeColors.tertiaryText(colorScheme))
                    
                    Text(timeAgoString)
                        .font(.system(size: 12))
                        .foregroundStyle(ThemeColors.tertiaryText(colorScheme))
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor)
        )
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            Button {
                editedTitle = conversation.title
                isRenaming = true
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            
            Button {
                // Export functionality placeholder
                print("Export conversation: \(conversation.title)")
            } label: {
                Label("Export", systemImage: "square.and.arrow.down")
            }
            
            Button {
                conversationStore.duplicateConversation(conversation)
            } label: {
                Label("Duplicate", systemImage: "doc.on.doc")
            }
            
            Divider()
            
            Button(role: .destructive) {
                conversationStore.deleteConversation(conversation)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return ThemeColors.selectedBackground(colorScheme)
        } else if isHovered {
            return ThemeColors.hoverBackground(colorScheme)
        } else {
            return .clear
        }
    }
    
    private var modelDisplayName: String {
        AIModel.model(for: conversation.modelId)?.displayName ?? "Unknown Model"
    }
    
    private var timeAgoString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: conversation.updatedAt, relativeTo: Date())
    }
}

#Preview {
    VStack {
        ConversationRowView(
            conversation: Conversation(
                title: "macOS App PRD Discussion",
                modelId: "anthropic.claude-3-5-sonnet"
            ),
            isSelected: true
        )
        ConversationRowView(
            conversation: Conversation(
                title: "Swift async/await patterns",
                modelId: "anthropic.claude-3-opus"
            ),
            isSelected: false
        )
    }
    .frame(width: 260)
    .background(Color(hex: "F0F0F1"))
    .environment(ConversationStore())
}
