//
//  GuestMessageBanner.swift
//  ThinkTank
//
//  Created by John Gambrell on 1/31/26.
//

import SwiftUI

/// Banner displayed for guest users showing remaining free messages
struct GuestMessageBanner: View {
    let remainingMessages: Int
    let maxMessages: Int
    let onUpgrade: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var isLowOnMessages: Bool {
        remainingMessages <= 3
    }
    
    private var isOutOfMessages: Bool {
        remainingMessages <= 0
    }
    
    private var bannerColor: Color {
        if isOutOfMessages {
            return Color.destructive.opacity(0.15)
        } else if isLowOnMessages {
            return Color.orange.opacity(0.15)
        } else {
            return Color.brandPrimaryLight.opacity(0.5)
        }
    }
    
    private var textColor: Color {
        if isOutOfMessages {
            return Color.destructive
        } else if isLowOnMessages {
            return Color.orange
        } else {
            return ThemeColors.primaryText(colorScheme)
        }
    }
    
    private var iconColor: Color {
        if isOutOfMessages {
            return Color.destructive
        } else if isLowOnMessages {
            return Color.orange
        } else {
            return Color.brandPrimary
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isOutOfMessages ? "exclamationmark.circle.fill" : "sparkles")
                .font(.system(size: 16))
                .foregroundStyle(iconColor)
            
            if isOutOfMessages {
                Text("You've used all \(maxMessages) free messages")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(textColor)
            } else {
                Text("\(remainingMessages) free message\(remainingMessages == 1 ? "" : "s") remaining")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(textColor)
            }
            
            Spacer()
            
            Button(action: onUpgrade) {
                Text("Create Account")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.063, green: 0.725, blue: 0.506),
                                Color(red: 0.020, green: 0.588, blue: 0.412)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(bannerColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(iconColor.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

/// Overlay shown when guest has reached message limit
struct GuestLimitReachedOverlay: View {
    let onUpgrade: () -> Void
    let onSignOut: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.brandPrimary)
            
            VStack(spacing: 8) {
                Text("Free Trial Complete")
                    .font(.system(size: 24, weight: .bold))
                
                Text("You've used all 10 free messages.\nCreate an account to continue chatting and access your conversation history from any device.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            VStack(spacing: 12) {
                Button(action: onUpgrade) {
                    Text("Create Account")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.063, green: 0.725, blue: 0.506),
                                    Color(red: 0.020, green: 0.588, blue: 0.412)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(color: Color.brandPrimary.opacity(0.4), radius: 15, x: 0, y: 8)
                }
                .buttonStyle(.plain)
                
                Button(action: onSignOut) {
                    Text("Sign Out")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: 280)
        }
        .padding(40)
        .background(Color(.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
}

#Preview("Banner - Full") {
    VStack {
        GuestMessageBanner(remainingMessages: 10, maxMessages: 10, onUpgrade: {})
        GuestMessageBanner(remainingMessages: 5, maxMessages: 10, onUpgrade: {})
        GuestMessageBanner(remainingMessages: 3, maxMessages: 10, onUpgrade: {})
        GuestMessageBanner(remainingMessages: 1, maxMessages: 10, onUpgrade: {})
        GuestMessageBanner(remainingMessages: 0, maxMessages: 10, onUpgrade: {})
    }
    .padding()
    .frame(width: 600)
}

#Preview("Limit Reached Overlay") {
    ZStack {
        Color.gray.opacity(0.3)
        GuestLimitReachedOverlay(onUpgrade: {}, onSignOut: {})
    }
    .frame(width: 600, height: 500)
}
