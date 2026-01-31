//
//  EmptyStateView.swift
//  ThinkTank
//
//  Created by John Gambrell on 1/29/26.
//

import SwiftUI

struct EmptyStateView: View {
    @Environment(\.colorScheme) private var colorScheme
    
    let suggestions = [
        SuggestionCard(
            title: "Write code",
            description: "\"Help me build a SwiftUI component for...\""
        ),
        SuggestionCard(
            title: "Explain concepts",
            description: "\"What's the difference between async and...\""
        ),
        SuggestionCard(
            title: "Debug issues",
            description: "\"I'm getting this error in my Lambda...\""
        ),
        SuggestionCard(
            title: "Brainstorm ideas",
            description: "\"Help me design a system architecture...\""
        ),
        SuggestionCard(
            title: "Review code",
            description: "\"Can you review this function and suggest...\""
        ),
        SuggestionCard(
            title: "Write content",
            description: "\"Draft documentation for my API...\""
        )
    ]
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            Image("AppReference")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
            // Logo
           
            
            // Welcome Text
            VStack(spacing: 8) {
                Text("How can I help you today?")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(ThemeColors.primaryText(colorScheme))
                
                Text("Start a conversation with ThinkTank powered by AWS Bedrock")
                    .font(.system(size: 15))
                    .foregroundStyle(ThemeColors.secondaryText(colorScheme))
            }
            
            // Suggestion Cards
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                ForEach(suggestions) { suggestion in
                    SuggestionCardView(suggestion: suggestion)
                }
            }
            .padding(.horizontal, 60)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SuggestionCard: Identifiable {
    let id = UUID()
    let title: String
    let description: String
}

struct SuggestionCardView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered: Bool = false
    
    let suggestion: SuggestionCard
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(suggestion.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ThemeColors.primaryText(colorScheme))
            
            Text(suggestion.description)
                .font(.system(size: 12))
                .foregroundStyle(ThemeColors.tertiaryText(colorScheme))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHovered ? ThemeColors.hoverBackground(colorScheme) : ThemeColors.inputBackground(colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ThemeColors.border(colorScheme), lineWidth: 1)
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    EmptyStateView()
        .frame(width: 800, height: 600)
}
