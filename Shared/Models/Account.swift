//
//  Account.swift
//  SwiftUICustomActions
//
//  Created by Milos Bogdanovic on 10/31/24.
//

import Foundation


class Account: Codable, Identifiable {
    
    // MARK: - Properties
    
    var uuid: String? = UUID().uuidString
    var username: String?
    var email: String?
    var password: String
    
    // MARK: - Initialization
    
    init(username: String? = nil,
         email: String? = nil,
         password: String) {
        self.uuid = UUID().uuidString
        self.username = username
        self.email = email
        self.password = password
    }
    
    // MARK: - Public
    
    static var account: Account {
        Account(username: "Username", email: "test@email.com", password: "")
    }
    
    static var accounts: [Account] {
        [
            Account(username: "Username", email: "test@email.com", password: ""),
            Account(username: "Username", email: "test@email.com", password: ""),
            Account(username: "Username", email: "test@email.com", password: "")
        ]
    }
}
