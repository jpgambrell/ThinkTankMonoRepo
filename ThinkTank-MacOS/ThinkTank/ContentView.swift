//
//  ContentView.swift
//  ThinkTank
//
//  Created by John Gambrell on 1/29/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authService = CognitoAuthService.shared
    @StateObject private var conversationStore = ConversationStore()
    @StateObject private var themeManager = ThemeManager()
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
                MainView()
                    .environmentObject(conversationStore)
                    .environmentObject(themeManager)
                    .environmentObject(authService)
            } else {
                LoginView()
                    .environmentObject(authService)
            }
        }
        .preferredColorScheme(themeManager.currentTheme.colorScheme)
    }
}

#Preview {
    ContentView()
}
