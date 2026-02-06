import Foundation
import Observation

/// Handles Amazon Cognito authentication
@Observable
@MainActor
final class CognitoAuthService {
    var isAuthenticated = false
    var currentUser: User?
    var isLoading = false
    var errorMessage: String?
    
    @ObservationIgnored private var idToken: String?
    @ObservationIgnored private var accessToken: String?
    @ObservationIgnored private var refreshToken: String?
    
    // Singleton instance
    static let shared = CognitoAuthService()
    
    // MARK: - Guest Account Constants
    @ObservationIgnored private let isGuestAccountKey = "com.thinktank.isGuestAccount"
    @ObservationIgnored private let guestEmailKey = "com.thinktank.guestEmail"
    @ObservationIgnored private let guestPasswordKey = "com.thinktank.guestPassword"
    @ObservationIgnored private let freeMessageCountKey = "com.thinktank.freeMessageCount"
    @ObservationIgnored private let maxFreeMessages = 10
    
    // MARK: - Guest Account Properties (stored for @Observable tracking)
    
    /// Check if current account is a guest account
    var isGuestAccount: Bool = false {
        didSet { UserDefaults.standard.set(isGuestAccount, forKey: isGuestAccountKey) }
    }
    
    /// Current message count for free (non-Pro) users
    var freeMessageCount: Int = 0 {
        didSet { UserDefaults.standard.set(freeMessageCount, forKey: freeMessageCountKey) }
    }
    
    /// Remaining free messages before requiring upgrade
    var remainingFreeMessages: Int {
        max(0, maxFreeMessages - freeMessageCount)
    }
    
    /// Maximum allowed free messages
    var maxAllowedFreeMessages: Int {
        maxFreeMessages
    }
    
    // MARK: - Backward Compatibility (deprecated, use free message properties)
    
    @available(*, deprecated, renamed: "freeMessageCount")
    var guestMessageCount: Int {
        get { freeMessageCount }
        set { freeMessageCount = newValue }
    }
    
    @available(*, deprecated, renamed: "remainingFreeMessages")
    var remainingGuestMessages: Int {
        remainingFreeMessages
    }
    
    @available(*, deprecated, renamed: "maxAllowedFreeMessages")
    var maxAllowedGuestMessages: Int {
        maxAllowedFreeMessages
    }
    
    @available(*, deprecated, message: "Use subscription status to check message limits")
    var canGuestSendMessage: Bool {
        freeMessageCount < maxFreeMessages
    }
    
    private init() {
        // Load guest state from UserDefaults
        isGuestAccount = UserDefaults.standard.bool(forKey: isGuestAccountKey)
        
        // Migrate old guest message count to new free message count key if needed
        if UserDefaults.standard.object(forKey: freeMessageCountKey) == nil {
            let oldCount = UserDefaults.standard.integer(forKey: "com.thinktank.guestMessageCount")
            freeMessageCount = oldCount
        } else {
            freeMessageCount = UserDefaults.standard.integer(forKey: freeMessageCountKey)
        }
        
        // Check for stored tokens on init
        loadStoredTokens()
    }
    
    // MARK: - Public Methods
    
    /// Register a new user with email and password
    func signUp(email: String, password: String, fullName: String) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        let endpoint = "https://cognito-idp.\(AWSConfig.cognitoRegion).amazonaws.com/"
        
        let payload: [String: Any] = [
            "ClientId": AWSConfig.cognitoClientId,
            "Username": email,
            "Password": password,
            "UserAttributes": [
                ["Name": "email", "Value": email],
                ["Name": "name", "Value": fullName]
            ]
        ]
        
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-amz-json-1.1", forHTTPHeaderField: "Content-Type")
        request.setValue("AWSCognitoIdentityProviderService.SignUp", forHTTPHeaderField: "X-Amz-Target")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError("Invalid response")
        }
        
        if httpResponse.statusCode == 200 {
            // Registration successful - user should now sign in
            // Don't auto-sign in; let user go back to login screen
            return
        } else {
            let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let message = errorResponse?["message"] as? String ?? "Registration failed"
            throw AuthError.registrationFailed(message)
        }
    }
    
    /// Sign in with email and password
    func signIn(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        let endpoint = "https://cognito-idp.\(AWSConfig.cognitoRegion).amazonaws.com/"
        
        let payload: [String: Any] = [
            "ClientId": AWSConfig.cognitoClientId,
            "AuthFlow": "USER_PASSWORD_AUTH",
            "AuthParameters": [
                "USERNAME": email,
                "PASSWORD": password
            ]
        ]
        
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-amz-json-1.1", forHTTPHeaderField: "Content-Type")
        request.setValue("AWSCognitoIdentityProviderService.InitiateAuth", forHTTPHeaderField: "X-Amz-Target")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError("Invalid response")
        }
        
        if httpResponse.statusCode == 200 {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let authResult = json?["AuthenticationResult"] as? [String: Any] else {
                throw AuthError.signInFailed("Invalid response format")
            }
            
            idToken = authResult["IdToken"] as? String
            accessToken = authResult["AccessToken"] as? String
            refreshToken = authResult["RefreshToken"] as? String
            
            // Store tokens securely
            storeTokens()
            
            // Parse user info from ID token
            try parseUserFromToken()
            
            isAuthenticated = true
        } else {
            let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let message = errorResponse?["message"] as? String ?? "Sign in failed"
            throw AuthError.signInFailed(message)
        }
    }
    
    /// Sign out the current user
    func signOut() {
        idToken = nil
        accessToken = nil
        refreshToken = nil
        currentUser = nil
        isAuthenticated = false
        
        // Clear stored tokens
        UserDefaults.standard.removeObject(forKey: "idToken")
        UserDefaults.standard.removeObject(forKey: "accessToken")
        UserDefaults.standard.removeObject(forKey: "refreshToken")
        
        // Clear guest data
        clearGuestData()
    }
    
    /// Permanently delete the user's account
    /// This is required by App Store guidelines for apps that offer account creation
    func deleteAccount() async throws {
        guard let token = accessToken else {
            throw AuthError.notAuthenticated
        }
        
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        let endpoint = "https://cognito-idp.\(AWSConfig.cognitoRegion).amazonaws.com/"
        
        guard let url = URL(string: endpoint) else {
            throw AuthError.networkError("Invalid URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-amz-json-1.1", forHTTPHeaderField: "Content-Type")
        request.setValue("AWSCognitoIdentityProviderService.DeleteUser", forHTTPHeaderField: "X-Amz-Target")
        
        let payload: [String: Any] = [
            "AccessToken": token
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError("Invalid response")
        }
        
        // 200 means success for DeleteUser
        guard httpResponse.statusCode == 200 else {
            throw AuthError.networkError("Failed to delete account. Please try again.")
        }
        
        // Clear all local data after successful deletion
        signOut()
        
        // Also clear message count
        UserDefaults.standard.removeObject(forKey: freeMessageCountKey)
        
        print("✅ Account deleted successfully")
    }
    
    /// Get the current ID token for API requests, refreshing automatically if expired
    func getIdToken() async throws -> String {
        guard let token = idToken else {
            throw AuthError.notAuthenticated
        }
        
        // Check if token is expired (or will expire within 60 seconds)
        if isTokenExpired(token, bufferSeconds: 60) {
            print("🔄 ID token expired or expiring soon, attempting refresh...")
            do {
                try await refreshTokens()
                guard let freshToken = idToken else {
                    throw AuthError.notAuthenticated
                }
                return freshToken
            } catch {
                print("❌ Token refresh failed: \(error)")
                // Clear auth state so user is prompted to sign in again
                signOut()
                throw AuthError.notAuthenticated
            }
        }
        
        return token
    }
    
    // MARK: - Guest Account Methods
    
    /// Create a silent guest account with random credentials
    func createGuestAccount() async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        let guestId = UUID().uuidString.lowercased()
        let guestEmail = "guest_\(guestId)@thinktank.guest"
        let guestPassword = generateSecurePassword()
        
        // Sign up with guest credentials (auto-confirmed via Lambda trigger)
        try await signUpInternal(email: guestEmail, password: guestPassword, fullName: "Guest User")
        
        // Sign in immediately
        try await signInInternal(email: guestEmail, password: guestPassword)
        
        // Mark as guest account and store credentials for re-auth
        isGuestAccount = true
        UserDefaults.standard.set(guestEmail, forKey: guestEmailKey)
        UserDefaults.standard.set(guestPassword, forKey: guestPasswordKey)
        freeMessageCount = 0
        
        isAuthenticated = true
    }
    
    /// Upgrade guest account to full account
    func upgradeGuestAccount(email: String, password: String, fullName: String) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        guard let token = idToken else {
            throw AuthError.notAuthenticated
        }
        
        // Call the upgrade endpoint
        let endpoint = "\(AWSConfig.apiBaseUrl)auth/upgrade"
        
        let payload: [String: Any] = [
            "email": email,
            "password": password,
            "fullName": fullName
        ]
        
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError("Invalid response")
        }
        
        if httpResponse.statusCode == 200 {
            // Clear guest flags but keep message count (they need to subscribe for unlimited)
            isGuestAccount = false
            UserDefaults.standard.removeObject(forKey: guestEmailKey)
            UserDefaults.standard.removeObject(forKey: guestPasswordKey)
            
            // Sign in with new credentials to get fresh tokens
            try await signIn(email: email, password: password)
            
            // Update user info
            currentUser = User(fullName: fullName, email: email)
        } else {
            if let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = errorResponse["error"] as? String {
                throw AuthError.upgradeFailed(errorMessage)
            }
            throw AuthError.upgradeFailed("Upgrade failed")
        }
    }
    
    /// Increment free message count (call after successful message send for non-Pro users)
    func incrementFreeMessageCount() {
        freeMessageCount += 1
    }
    
    /// Reset message count (call when user subscribes to Pro)
    func resetMessageCount() {
        freeMessageCount = 0
    }
    
    /// Clear all guest-related data
    func clearGuestData() {
        isGuestAccount = false
        freeMessageCount = 0
        UserDefaults.standard.removeObject(forKey: guestEmailKey)
        UserDefaults.standard.removeObject(forKey: guestPasswordKey)
    }
    
    // MARK: - Backward Compatibility
    
    @available(*, deprecated, renamed: "incrementFreeMessageCount")
    func incrementGuestMessageCount() {
        incrementFreeMessageCount()
    }
    
    /// Generate a secure random password that meets Cognito requirements
    private func generateSecurePassword() -> String {
        let lowercase = "abcdefghijklmnopqrstuvwxyz"
        let uppercase = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let digits = "0123456789"
        let special = "!@#$%^&*"
        
        // Ensure at least one of each required character type
        var password = ""
        password += String(lowercase.randomElement()!)
        password += String(uppercase.randomElement()!)
        password += String(digits.randomElement()!)
        password += String(special.randomElement()!)
        
        // Fill remaining with random characters from all sets
        let allChars = lowercase + uppercase + digits + special
        for _ in 0..<12 {
            password += String(allChars.randomElement()!)
        }
        
        // Shuffle the password
        return String(password.shuffled())
    }
    
    // MARK: - Token Refresh
    
    /// Check if a JWT token is expired
    private func isTokenExpired(_ token: String, bufferSeconds: TimeInterval = 0) -> Bool {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return true }
        
        var base64 = String(parts[1])
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = json["exp"] as? TimeInterval else {
            return true
        }
        
        let expirationDate = Date(timeIntervalSince1970: exp)
        return Date().addingTimeInterval(bufferSeconds) >= expirationDate
    }
    
    /// Refresh tokens using the Cognito REFRESH_TOKEN_AUTH flow
    private func refreshTokens() async throws {
        guard let currentRefreshToken = refreshToken else {
            throw AuthError.notAuthenticated
        }
        
        let endpoint = "https://cognito-idp.\(AWSConfig.cognitoRegion).amazonaws.com/"
        
        let payload: [String: Any] = [
            "ClientId": AWSConfig.cognitoClientId,
            "AuthFlow": "REFRESH_TOKEN_AUTH",
            "AuthParameters": [
                "REFRESH_TOKEN": currentRefreshToken
            ]
        ]
        
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-amz-json-1.1", forHTTPHeaderField: "Content-Type")
        request.setValue("AWSCognitoIdentityProviderService.InitiateAuth", forHTTPHeaderField: "X-Amz-Target")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError("Invalid response during token refresh")
        }
        
        if httpResponse.statusCode == 200 {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let authResult = json?["AuthenticationResult"] as? [String: Any] else {
                throw AuthError.signInFailed("Invalid refresh response format")
            }
            
            idToken = authResult["IdToken"] as? String
            accessToken = authResult["AccessToken"] as? String
            // Note: REFRESH_TOKEN_AUTH does not return a new refresh token;
            // the existing one remains valid
            
            // Persist the new tokens
            storeTokens()
            
            // Update user info from the new token
            try parseUserFromToken()
            
            print("✅ Tokens refreshed successfully")
        } else {
            let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let message = errorResponse?["message"] as? String ?? "Token refresh failed"
            print("❌ Token refresh error: \(message)")
            throw AuthError.signInFailed(message)
        }
    }
    
    // MARK: - Private Methods
    
    /// Internal sign up without loading state management (for guest account creation)
    private func signUpInternal(email: String, password: String, fullName: String) async throws {
        let endpoint = "https://cognito-idp.\(AWSConfig.cognitoRegion).amazonaws.com/"
        
        let payload: [String: Any] = [
            "ClientId": AWSConfig.cognitoClientId,
            "Username": email,
            "Password": password,
            "UserAttributes": [
                ["Name": "email", "Value": email],
                ["Name": "name", "Value": fullName]
            ]
        ]
        
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-amz-json-1.1", forHTTPHeaderField: "Content-Type")
        request.setValue("AWSCognitoIdentityProviderService.SignUp", forHTTPHeaderField: "X-Amz-Target")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError("Invalid response")
        }
        
        if httpResponse.statusCode != 200 {
            let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let message = errorResponse?["message"] as? String ?? "Registration failed"
            throw AuthError.registrationFailed(message)
        }
    }
    
    /// Internal sign in without loading state management (for guest account creation)
    private func signInInternal(email: String, password: String) async throws {
        let endpoint = "https://cognito-idp.\(AWSConfig.cognitoRegion).amazonaws.com/"
        
        let payload: [String: Any] = [
            "ClientId": AWSConfig.cognitoClientId,
            "AuthFlow": "USER_PASSWORD_AUTH",
            "AuthParameters": [
                "USERNAME": email,
                "PASSWORD": password
            ]
        ]
        
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-amz-json-1.1", forHTTPHeaderField: "Content-Type")
        request.setValue("AWSCognitoIdentityProviderService.InitiateAuth", forHTTPHeaderField: "X-Amz-Target")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError("Invalid response")
        }
        
        if httpResponse.statusCode == 200 {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let authResult = json?["AuthenticationResult"] as? [String: Any] else {
                throw AuthError.signInFailed("Invalid response format")
            }
            
            idToken = authResult["IdToken"] as? String
            accessToken = authResult["AccessToken"] as? String
            refreshToken = authResult["RefreshToken"] as? String
            
            // Store tokens securely
            storeTokens()
            
            // Parse user info from ID token
            try parseUserFromToken()
        } else {
            let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let message = errorResponse?["message"] as? String ?? "Sign in failed"
            throw AuthError.signInFailed(message)
        }
    }
    
    private func storeTokens() {
        if let idToken = idToken {
            UserDefaults.standard.set(idToken, forKey: "idToken")
        }
        if let accessToken = accessToken {
            UserDefaults.standard.set(accessToken, forKey: "accessToken")
        }
        if let refreshToken = refreshToken {
            UserDefaults.standard.set(refreshToken, forKey: "refreshToken")
        }
    }
    
    private func loadStoredTokens() {
        idToken = UserDefaults.standard.string(forKey: "idToken")
        accessToken = UserDefaults.standard.string(forKey: "accessToken")
        refreshToken = UserDefaults.standard.string(forKey: "refreshToken")
        
        if let token = idToken {
            if isTokenExpired(token) {
                // Token is expired but we might have a refresh token
                if refreshToken != nil {
                    print("🔄 Stored ID token is expired, will refresh on next API call")
                    // Still mark as authenticated — getIdToken() will handle the refresh
                    // Try to parse user info (it's just name/email, still readable from expired token)
                    try? parseUserFromToken()
                    isAuthenticated = true
                } else {
                    // No refresh token, must sign in again
                    signOut()
                }
            } else {
                do {
                    try parseUserFromToken()
                    isAuthenticated = true
                } catch {
                    signOut()
                }
            }
        }
    }
    
    private func parseUserFromToken() throws {
        guard let idToken = idToken else {
            throw AuthError.notAuthenticated
        }
        
        // JWT tokens are base64 encoded and have 3 parts separated by dots
        let parts = idToken.split(separator: ".")
        guard parts.count == 3 else {
            throw AuthError.invalidToken
        }
        
        // Decode the payload (second part)
        var base64 = String(parts[1])
        // Add padding if needed
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AuthError.invalidToken
        }
        
        let email = json["email"] as? String ?? ""
        let name = json["name"] as? String ?? email.components(separatedBy: "@").first ?? "User"
        
        currentUser = User(
            fullName: name,
            email: email
        )
    }
}

// MARK: - Error Types

enum AuthError: LocalizedError {
    case networkError(String)
    case registrationFailed(String)
    case signInFailed(String)
    case notAuthenticated
    case invalidToken
    case upgradeFailed(String)
    case guestLimitReached
    
    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Network error: \(message)"
        case .registrationFailed(let message):
            return message
        case .signInFailed(let message):
            return message
        case .notAuthenticated:
            return "Not authenticated"
        case .invalidToken:
            return "Invalid authentication token"
        case .upgradeFailed(let message):
            return "Account upgrade failed: \(message)"
        case .guestLimitReached:
            return "You've used all 10 free messages. Create an account to continue chatting."
        }
    }
}
