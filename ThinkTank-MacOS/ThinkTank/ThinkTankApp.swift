//
//  ThinkTankApp.swift
//  ThinkTank
//
//  Created by John Gambrell on 1/29/26.
//

import SwiftUI

@main
struct ThinkTankApp: App {
    
    init() {
        // Configure RevenueCat SDK
        SubscriptionService.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1200, height: 800)
        .commands {
            // Custom menu commands
            CommandGroup(replacing: .newItem) {
                Button("New Chat") {
                    NotificationCenter.default.post(name: .newChatRequested, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            
            CommandGroup(after: .appSettings) {
                Button("Settings...") {
                    NotificationCenter.default.post(name: .settingsRequested, object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let newChatRequested = Notification.Name("newChatRequested")
    static let settingsRequested = Notification.Name("settingsRequested")
}
