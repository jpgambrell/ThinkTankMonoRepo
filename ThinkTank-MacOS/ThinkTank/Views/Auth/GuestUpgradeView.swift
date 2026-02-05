//
//  GuestUpgradeView.swift
//  ThinkTank
//
//  Created by John Gambrell on 1/31/26.
//

import SwiftUI

/// View for upgrading a guest account to a full account
struct GuestUpgradeView: View {
    @Environment(CognitoAuthService.self) private var authService
    @Environment(\.colorScheme) private var colorScheme
    
    @Binding var isPresented: Bool
    
    /// Callback when account is successfully created - used to show paywall
    var onAccountCreated: (() -> Void)?
    
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?
    @State private var isUpgrading = false
    
    var body: some View {
        ZStack {
            // Background - solid color to cover underlying content
            ThemeColors.windowBackground(colorScheme)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Spacer()
                    
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Logo and Title
                        VStack(spacing: 8) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 48))
                                .foregroundStyle(Color.brandPrimary)
                            
                            Text("Create Your Account")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.primary)
                            
                            Text("Your chat history will be preserved")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 20)
                        
                        // Upgrade Form
                        VStack(spacing: 14) {
                            // Benefits callout
                            VStack(alignment: .leading, spacing: 8) {
                                BenefitRow(icon: "checkmark.circle.fill", text: "Keep all your conversations")
                                BenefitRow(icon: "iphone.and.arrow.forward", text: "Access from any device")
                                BenefitRow(icon: "infinity", text: "Unlimited messages")
                            }
                            .padding(12)
                            .background(Color.brandPrimaryLight.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    
                    // Full Name Field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Full Name")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        
                        TextField("John Doe", text: $fullName)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14))
                            .padding(10)
                            .background(Color(.textBackgroundColor))
                            .clipShape(.rect(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                            .textContentType(.name)
                    }
                    
                    // Email Field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Email")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        
                        TextField("you@example.com", text: $email)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14))
                            .padding(10)
                            .background(Color(.textBackgroundColor))
                            .clipShape(.rect(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                            .textContentType(.emailAddress)
                            .disableAutocorrection(true)
                    }
                    
                    // Password Field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Password")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        
                        SecureField("At least 8 characters", text: $password)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14))
                            .padding(10)
                            .background(Color(.textBackgroundColor))
                            .clipShape(.rect(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                            .textContentType(.newPassword)
                    }
                    
                    // Confirm Password Field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Confirm Password")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        
                        SecureField("Re-enter password", text: $confirmPassword)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14))
                            .padding(10)
                            .background(Color(.textBackgroundColor))
                            .clipShape(.rect(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                            .textContentType(.newPassword)
                    }
                    
                    // Password Requirements
                    if !password.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            PasswordRequirement(
                                met: password.count >= 8,
                                text: "At least 8 characters"
                            )
                            PasswordRequirement(
                                met: password.rangeOfCharacter(from: .uppercaseLetters) != nil,
                                text: "One uppercase letter"
                            )
                            PasswordRequirement(
                                met: password.rangeOfCharacter(from: .lowercaseLetters) != nil,
                                text: "One lowercase letter"
                            )
                            PasswordRequirement(
                                met: password.rangeOfCharacter(from: .decimalDigits) != nil,
                                text: "One number"
                            )
                        }
                        .font(.system(size: 11))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Password match indicator
                    if !confirmPassword.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: password == confirmPassword ? "checkmark.circle.fill" : "xmark.circle.fill")
                            Text(password == confirmPassword ? "Passwords match" : "Passwords don't match")
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(password == confirmPassword ? Color.brandPrimary : .red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Error Message
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 12))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Create Account Button
                    Button(action: upgradeAccount) {
                        if isUpgrading {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .controlSize(.small)
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Create Account")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(height: 40)
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
                    .clipShape(.rect(cornerRadius: 6))
                    .shadow(color: Color.brandPrimary.opacity(0.3), radius: 10, x: 0, y: 4)
                    .disabled(isUpgrading || !isFormValid)
                    .opacity(isFormValid ? 1.0 : 0.5)
                        }
                        .frame(maxWidth: 440)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        !fullName.isEmpty &&
        !email.isEmpty &&
        email.contains("@") &&
        password.count >= 8 &&
        password == confirmPassword &&
        passwordMeetsRequirements
    }
    
    private var passwordMeetsRequirements: Bool {
        password.rangeOfCharacter(from: .uppercaseLetters) != nil &&
        password.rangeOfCharacter(from: .lowercaseLetters) != nil &&
        password.rangeOfCharacter(from: .decimalDigits) != nil
    }
    
    private func upgradeAccount() {
        errorMessage = nil
        isUpgrading = true
        
        Task {
            do {
                try await authService.upgradeGuestAccount(
                    email: email,
                    password: password,
                    fullName: fullName
                )
                await MainActor.run {
                    isUpgrading = false
                    // Dismiss this view and trigger callback to show paywall
                    isPresented = false
                    onAccountCreated?()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isUpgrading = false
                }
            }
        }
    }
}

/// Helper view for benefit callouts
private struct BenefitRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(Color.brandPrimary)
            
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
        }
    }
}

#Preview {
    GuestUpgradeView(isPresented: .constant(true))
        .environment(CognitoAuthService.shared)
        .frame(width: 600, height: 800)
}
