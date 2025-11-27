//
//  RootView.swift
//  Eloquence
//
//  Created by Johannes Gruber on 10.11.25.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var userSession: UserSession
    
    var body: some View {
        ZStack {
            if userSession.isLoggedIn {
                DashboardView()
                    .transition(.opacity)
            } else {
                LoginView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: userSession.isLoggedIn)
    }
}

#Preview {
    RootView()
        .environmentObject(UserSession())
}

