//
//  User.swift
//  ThinkTank
//
//  Created by John Gambrell on 1/29/26.
//

import Foundation

struct User: Identifiable, Equatable {
    let id: UUID
    var fullName: String
    var email: String
    var avatarInitials: String {
        let components = fullName.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        }
        return String(fullName.prefix(2)).uppercased()
    }
    
    init(
        id: UUID = UUID(),
        fullName: String,
        email: String
    ) {
        self.id = id
        self.fullName = fullName
        self.email = email
    }
    
    // Mock user for development
    static let mock = User(
        fullName: "John Doe",
        email: "john@example.com"
    )
}
