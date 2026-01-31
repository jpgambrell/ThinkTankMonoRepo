//
//  ContentView.swift
//  ThinkTank
//
//  Created by John Gambrell on 1/29/26.
//

import SwiftUI

struct ContentView: View {
    @State private var authService = CognitoAuthService.shared
    @State private var conversationStore = ConversationStore()
    @State private var themeManager = ThemeManager()
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
                MainView()
                    .environment(conversationStore)
                    .environment(themeManager)
                    .environment(authService)
            } else {
                LoginView()
                    .environment(authService)
            }
        }
        .preferredColorScheme(themeManager.currentTheme.colorScheme)
        .onChange(of: authService.isAuthenticated) { oldValue, newValue in
            if newValue && !oldValue {
                // User just logged in - load conversations from cloud
                Task {
                    await conversationStore.loadConversationsFromCloud()
                }
            } else if !newValue && oldValue {
                // User logged out - clear local conversations
                conversationStore.conversations = []
                conversationStore.selectedConversationId = nil
            }
        }
        .task {
            // Also check on app launch if already authenticated
            if authService.isAuthenticated {
                await conversationStore.loadConversationsFromCloud()
            }
        }
    }
}

#Preview {
    ContentView()
}
