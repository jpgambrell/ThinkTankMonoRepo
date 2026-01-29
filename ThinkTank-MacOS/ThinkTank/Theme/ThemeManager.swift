//
//  ThemeManager.swift
//  ThinkTank
//
//  Created by John Gambrell on 1/29/26.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class ThemeManager: ObservableObject {
    @Published var currentTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "appTheme")
        }
    }
    
    init() {
        let savedTheme = UserDefaults.standard.string(forKey: "appTheme") ?? AppTheme.system.rawValue
        self.currentTheme = AppTheme(rawValue: savedTheme) ?? .system
    }
    
    func setTheme(_ theme: AppTheme) {
        withAnimation(.easeInOut(duration: 0.2)) {
            currentTheme = theme
        }
    }
}
