//
//  ContentView.swift
//  Eloquence
//
//  Created by Johannes Gruber on 10.11.25.
//
//  This file is deprecated in favor of RootView.swift
//  Kept for backwards compatibility

import SwiftUI

struct ContentView: View {
    var body: some View {
        RootView()
    }
}

#Preview {
    ContentView()
        .environmentObject(UserSession())
}
