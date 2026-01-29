import SwiftUI

struct RegistrationView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: CognitoAuthService
    
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            // Background
            Color.brandPrimary.opacity(0.03)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
                Spacer()
                
                // Logo and Title
                VStack(spacing: 16) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 80))
                        .foregroundStyle(Color.brandPrimary)
                    
                    Text("Create Account")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.primary)
                    
                    Text("Join ThinkTank to start chatting with AI")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 40)
                
                // Registration Form
                VStack(spacing: 20) {
                    // Full Name Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Full Name")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                        
                        TextField("John Doe", text: $fullName)
                            .textFieldStyle(.plain)
                            .font(.system(size: 15))
                            .padding(12)
                            .background(Color(.textBackgroundColor))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                            .textContentType(.name)
                    }
                    
                    // Email Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                        
                        TextField("you@example.com", text: $email)
                            .textFieldStyle(.plain)
                            .font(.system(size: 15))
                            .padding(12)
                            .background(Color(.textBackgroundColor))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                            .textContentType(.emailAddress)
                            .disableAutocorrection(true)
                    }
                    
                    // Password Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                        
                        SecureField("At least 8 characters", text: $password)
                            .textFieldStyle(.plain)
                            .font(.system(size: 15))
                            .padding(12)
                            .background(Color(.textBackgroundColor))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                            .textContentType(.newPassword)
                    }
                    
                    // Confirm Password Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Confirm Password")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                        
                        SecureField("Re-enter password", text: $confirmPassword)
                            .textFieldStyle(.plain)
                            .font(.system(size: 15))
                            .padding(12)
                            .background(Color(.textBackgroundColor))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                            .textContentType(.newPassword)
                    }
                    
                    // Password Requirements
                    if !password.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
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
                        .font(.system(size: 12))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Error Message
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Create Account Button
                    Button(action: register) {
                        if authService.isLoading {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .controlSize(.small)
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Create Account")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(height: 44)
                    .background(Color.brandPrimary)
                    .cornerRadius(8)
                    .disabled(authService.isLoading || !isFormValid)
                    .opacity(isFormValid ? 1.0 : 0.5)
                    .padding(.top, 8)
                }
                .frame(maxWidth: 360)
                .padding(.horizontal, 24)
                
                Spacer()
                Spacer()
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
    
    private func register() {
        errorMessage = nil
        
        Task {
            do {
                try await authService.signUp(email: email, password: password, fullName: fullName)
                // On success, dismiss and user will be signed in
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// Helper view for password requirements
struct PasswordRequirement: View {
    let met: Bool
    let text: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(met ? Color.brandPrimary : .secondary)
                .font(.system(size: 12))
            
            Text(text)
                .foregroundStyle(met ? .primary : .secondary)
        }
    }
}

#Preview {
    RegistrationView()
        .environmentObject(CognitoAuthService.shared)
        .frame(width: 1200, height: 800)
}
