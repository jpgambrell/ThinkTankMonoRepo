//
//  SettingsView.swift
//  ThinkTank
//
//  Created by John Gambrell on 1/29/26.
//

import SwiftUI

struct SettingsView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(CognitoAuthService.self) private var authService
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedModel: AIModel = AIModel.defaultModel
    @State private var streamingEnabled: Bool = true
    @State private var fontSize: FontSize = .medium
    
    private var user: User {
        authService.currentUser ?? User.mock
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .medium))
                        Text("Back")
                            .font(.system(size: 14))
                    }
                    .foregroundStyle(ThemeColors.secondaryText(colorScheme))
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text("Settings")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ThemeColors.primaryText(colorScheme))
                
                Spacer()
                
                // Balance the back button
                Color.clear
                    .frame(width: 60)
            }
            .padding(.horizontal, 24)
            .frame(height: 56)
            .background(ThemeColors.cardBackground(colorScheme))
            
            Divider()
            
            // Settings Content
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    // Account Section
                    SettingsSectionView(title: "ACCOUNT") {
                        VStack(spacing: 0) {
                            // Profile Row
                            HStack(spacing: 16) {
                                Circle()
                                    .fill(Color.brandPrimary)
                                    .frame(width: 56, height: 56)
                                    .overlay(
                                        Text(user.avatarInitials)
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundStyle(.white)
                                    )
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(user.fullName)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(ThemeColors.primaryText(colorScheme))
                                    
                                    Text(user.email)
                                        .font(.system(size: 13))
                                        .foregroundStyle(ThemeColors.secondaryText(colorScheme))
                                }
                                
                                Spacer()
                                
                                Button("Edit") {
                                    // Edit profile placeholder
                                }
                                .buttonStyle(SecondaryButtonStyle())
                            }
                            .padding(20)
                            
                            Divider()
                                .padding(.horizontal, 20)
                            
                            // Change Password Row
                            SettingsRowButton(title: "Change Password", action: {
                                // Change password placeholder
                            })
                        }
                    }
                    
                    // Model Preferences Section
                    SettingsSectionView(title: "MODEL PREFERENCES") {
                        VStack(spacing: 0) {
                            // Default Model
                            HStack {
                                Text("Default Model")
                                    .font(.system(size: 14))
                                    .foregroundStyle(ThemeColors.primaryText(colorScheme))
                                
                                Spacer()
                                
                                Picker("", selection: $selectedModel) {
                                    ForEach(AIModel.availableModels) { model in
                                        Text(model.displayName).tag(model)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 200)
                            }
                            .padding(20)
                            
                            Divider()
                                .padding(.horizontal, 20)
                            
                            // Streaming Toggle
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Enable Streaming Responses")
                                        .font(.system(size: 14))
                                        .foregroundStyle(ThemeColors.primaryText(colorScheme))
                                    
                                    Text("Show responses as they're generated")
                                        .font(.system(size: 12))
                                        .foregroundStyle(ThemeColors.tertiaryText(colorScheme))
                                }
                                
                                Spacer()
                                
                                Toggle("", isOn: $streamingEnabled)
                                    .toggleStyle(.switch)
                                    .tint(Color.brandPrimary)
                            }
                            .padding(20)
                        }
                    }
                    
                    // Appearance Section
                    SettingsSectionView(title: "APPEARANCE") {
                        VStack(spacing: 0) {
                            // Theme
                            HStack {
                                Text("Theme")
                                    .font(.system(size: 14))
                                    .foregroundStyle(ThemeColors.primaryText(colorScheme))
                                
                                Spacer()
                                
                                @Bindable var bindableTheme = themeManager
                                Picker("", selection: $bindableTheme.currentTheme) {
                                    ForEach(AppTheme.allCases) { theme in
                                        Label(theme.rawValue, systemImage: theme.iconName)
                                            .tag(theme)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 150)
                            }
                            .padding(20)
                            
                            Divider()
                                .padding(.horizontal, 20)
                            
                            // Font Size
                            HStack {
                                Text("Font Size")
                                    .font(.system(size: 14))
                                    .foregroundStyle(ThemeColors.primaryText(colorScheme))
                                
                                Spacer()
                                
                                Picker("", selection: $fontSize) {
                                    ForEach(FontSize.allCases) { size in
                                        Text(size.rawValue).tag(size)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 150)
                            }
                            .padding(20)
                        }
                    }
                    
                    // Keyboard Shortcuts Section
                    SettingsSectionView(title: "KEYBOARD SHORTCUTS") {
                        SettingsRowButton(title: "View All Shortcuts", action: {
                            // View shortcuts placeholder
                        })
                    }
                    
                    // Sign Out Button
                    Button(action: {
                        authService.signOut()
                        dismiss()
                    }) {
                        Text("Sign Out")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.destructive)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.destructive, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 100)
                }
                .padding(.vertical, 32)
                .padding(.horizontal, 100)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ThemeColors.cardBackground(colorScheme))
    }
}

// MARK: - Settings Section View
struct SettingsSectionView<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ThemeColors.tertiaryText(colorScheme))
                .tracking(0.5)
            
            VStack(spacing: 0) {
                content
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ThemeColors.inputBackground(colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(ThemeColors.border(colorScheme), lineWidth: 1)
            )
        }
    }
}

// MARK: - Settings Row Button
struct SettingsRowButton: View {
    let title: String
    let action: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered: Bool = false
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 14))
                    .foregroundStyle(ThemeColors.primaryText(colorScheme))
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ThemeColors.tertiaryText(colorScheme))
            }
            .padding(20)
            .background(isHovered ? ThemeColors.hoverBackground(colorScheme) : .clear)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Button Styles
struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color.brandPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(ThemeColors.cardBackground(colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(ThemeColors.border(colorScheme), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

// MARK: - Font Size Enum
enum FontSize: String, CaseIterable, Identifiable {
    case small = "Small"
    case medium = "Medium"
    case large = "Large"
    
    var id: String { rawValue }
}

#Preview {
    SettingsView()
        .frame(width: 800, height: 700)
        .environment(ThemeManager())
        .environment(CognitoAuthService.shared)
}
