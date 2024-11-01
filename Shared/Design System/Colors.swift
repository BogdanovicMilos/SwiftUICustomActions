//
//  Colors.swift
//  SwiftUICustomActions
//
//  Created by Milos Bogdanovic on 10/31/24.
//

import SwiftUI

extension Color {
    
    enum AppColorName: String {
        case actionPrimary = "Action Primary"
    }
    
    static let appActionPrimary = Color(AppColorName.actionPrimary.rawValue)
    static let accountBackgroundPrimary = UIColor(Color(red: 213 / 255, green: 220 / 255, blue: 255 / 250))
}
