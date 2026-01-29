//
//  SidebarView.swift
//  ThinkTank
//
//  Created by John Gambrell on 1/29/26.
//

import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var conversationStore: ConversationStore
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme
    
    @State private var searchText: String = ""
    @Binding var showSettings: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // New Chat Button
            Button(action: {
                _ = conversationStore.createNewConversation()
            }) {
                HStack {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                    Text("New Chat")
                        .font(.system(size: 14, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(ThemeColors.cardBackground(colorScheme))
                .foregroundColor(ThemeColors.primaryText(colorScheme))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(ThemeColors.border(colorScheme), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            // Search Field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(ThemeColors.placeholderText(colorScheme))
                
                TextField("Search chats...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(ThemeColors.placeholderText(colorScheme))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(ThemeColors.cardBackground(colorScheme))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(ThemeColors.border(colorScheme), lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            // Conversation List
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    let groupedConversations = conversationStore.conversationsGroupedByDate(searchText: searchText)
                    
                    ForEach(groupedConversations, id: \.0) { section, conversations in
                        Section {
                            ForEach(conversations) { conversation in
                                ConversationRowView(
                                    conversation: conversation,
                                    isSelected: conversation.id == conversationStore.selectedConversationId
                                )
                                .onTapGesture {
                                    conversationStore.selectConversation(conversation)
                                }
                            }
                        } header: {
                            SectionHeaderView(title: section)
                        }
                    }
                }
                .padding(.top, 8)
            }
            
            Spacer(minLength: 0)
            
            // User Profile Section
            UserProfileView(showSettings: $showSettings)
        }
        .frame(width: 260)
        .background(ThemeColors.sidebarBackground(colorScheme))
    }
}

struct SectionHeaderView: View {
    let title: String
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(ThemeColors.tertiaryText(colorScheme))
                .tracking(0.5)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(ThemeColors.sidebarBackground(colorScheme))
    }
}

#Preview {
    SidebarView(showSettings: .constant(false))
        .environmentObject(ConversationStore())
        .environmentObject(ThemeManager())
}
