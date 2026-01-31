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
    
    private init() {
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
    }
    
    /// Get the current ID token for API requests
    func getIdToken() async throws -> String {
        if let token = idToken {
            // TODO: Check if token is expired and refresh if needed
            return token
        }
        throw AuthError.notAuthenticated
    }
    
    // MARK: - Private Methods
    
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
        
        if idToken != nil {
            do {
                try parseUserFromToken()
                isAuthenticated = true
            } catch {
                // Token invalid or expired, clear it
                signOut()
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
        }
    }
}
