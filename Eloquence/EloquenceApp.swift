//
//  EloquenceApp.swift
//  Eloquence
//
//  Created by Johannes Gruber on 10.11.25.
//

import SwiftUI

@main
struct EloquenceApp: App {
    @StateObject private var userSession = UserSession()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(userSession)
        }
    }
}
