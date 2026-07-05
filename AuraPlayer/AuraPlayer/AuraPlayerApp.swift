//
//  AuraPlayerApp.swift
//  AuraPlayer
//
//  Created by mobile on 4/7/26.
//

import SwiftUI

@main
struct AuraPlayerApp: App {
    init() {
        AudioSessionManager.shared.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
