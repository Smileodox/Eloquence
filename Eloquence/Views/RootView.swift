//
//  RootView.swift
//  Eloquence
//
//  Created by Johannes Gruber on 10.11.25.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var userSession: UserSession
    @State private var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

    var body: some View {
        ZStack {
            if !hasCompletedOnboarding {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                    .transition(.opacity)
            } else if userSession.isLoggedIn {
                DashboardView()
                    .transition(.opacity)
            } else {
                LoginView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: hasCompletedOnboarding)
        .animation(.easeInOut, value: userSession.isLoggedIn)
    }
}

#Preview {
    RootView()
        .environmentObject(UserSession())
}

