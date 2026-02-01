import SwiftUI

struct LoginView: View {
    @Environment(CognitoAuthService.self) private var authService
    @State private var email = ""
    @State private var password = ""
    @State private var showingRegistration = false
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            // Background
            Color.brandPrimary.opacity(0.03)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Logo and Title
                VStack(spacing: 16) {
                    // ThinkTank Logo
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 80))
                        .foregroundStyle(Color.brandPrimary)
                    
                    Text("ThinkTank")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundStyle(.primary)
                    
                    Text("Sign in to continue")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 48)
                
                // Login Form
                VStack(spacing: 20) {
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
                            .clipShape(.rect(cornerRadius: 8))
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
                        
                        SecureField("Enter your password", text: $password)
                            .textFieldStyle(.plain)
                            .font(.system(size: 15))
                            .padding(12)
                            .background(Color(.textBackgroundColor))
                            .clipShape(.rect(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                            .textContentType(.password)
                    }
                    
                    // Error Message
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Sign In Button
                    Button(action: signIn) {
                        if authService.isLoading {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .controlSize(.small)
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Sign In")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(height: 44)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.063, green: 0.725, blue: 0.506), // #10B981
                                Color(red: 0.020, green: 0.588, blue: 0.412)  // #059669
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(.rect(cornerRadius: 8))
                    .shadow(color: Color.brandPrimary.opacity(0.4), radius: 15, x: 0, y: 8)
                    .disabled(authService.isLoading || !isFormValid)
                    .opacity(isFormValid ? 1.0 : 0.5)
                    .padding(.top, 8)
                    
                    // Try the App Button (Guest mode)
                    Button(action: tryAsGuest) {
                        HStack {
                            if authService.isLoading {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "sparkles")
                                Text("Try the App")
                                    .fontWeight(.medium)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .frame(height: 44)
                    .background(Color(.textBackgroundColor))
                    .clipShape(.rect(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .disabled(authService.isLoading)
                    
                    Text("Try with 10 free messages, no sign-up required")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    
                    // Register Link
                    HStack(spacing: 4) {
                        Text("Don't have an account?")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                        
                        Button("Sign Up") {
                            showingRegistration = true
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.brandPrimary)
                    }
                    .padding(.top, 8)
                }
                .frame(maxWidth: 360)
                .padding(.horizontal, 24)
                
                Spacer()
                Spacer()
            }
        }
        .sheet(isPresented: $showingRegistration) {
            RegistrationView()
                .environment(authService)
        }
    }
    
    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && email.contains("@")
    }
    
    private func signIn() {
        errorMessage = nil
        
        Task {
            do {
                try await authService.signIn(email: email, password: password)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func tryAsGuest() {
        errorMessage = nil
        
        Task {
            do {
                try await authService.createGuestAccount()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    LoginView()
        .environment(CognitoAuthService.shared)
        .frame(width: 1200, height: 800)
}
