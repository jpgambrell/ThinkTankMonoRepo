//
//  UserProfileView.swift
//  ThinkTank
//
//  Created by John Gambrell on 1/29/26.
//

import SwiftUI

struct UserProfileView: View {
    @Environment(CognitoAuthService.self) private var authService
    @Environment(\.colorScheme) private var colorScheme
    @Binding var showSettings: Bool
    
    private var user: User {
        authService.currentUser ?? User.mock
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(authService.isGuestAccount ? Color.gray : Color.brandPrimary)
                .frame(width: 36, height: 36)
                .overlay(
                    Text(user.avatarInitials)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                )
            
            // Name and Email
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(authService.isGuestAccount ? "Guest User" : user.fullName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(ThemeColors.primaryText(colorScheme))
                    
                    if authService.isGuestAccount {
                        Text("Trial")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.brandPrimary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.brandPrimaryLight)
                            .clipShape(Capsule())
                    }
                }
                
                Text(authService.isGuestAccount ? "Guest Account" : user.email)
                    .font(.system(size: 12))
                    .foregroundStyle(ThemeColors.secondaryText(colorScheme))
            }
            
            Spacer()
            
            // Settings Button
            Button(action: {
                showSettings = true
            }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 16))
                    .foregroundStyle(ThemeColors.secondaryText(colorScheme))
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(ThemeColors.userProfileBackground(colorScheme))
    }
}

#Preview {
    UserProfileView(showSettings: .constant(false))
        .frame(width: 260)
        .environment(CognitoAuthService.shared)
}
