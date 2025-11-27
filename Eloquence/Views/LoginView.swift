//
//  LoginView.swift
//  Eloquence
//
//  Created by Johannes Gruber on 10.11.25.
//

import SwiftUI
import Combine

struct LoginView: View {
    @EnvironmentObject var userSession: UserSession
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showPassword: Bool = false
    @FocusState private var focusedField: Field?
    
    enum Field {
        case email, password
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [.bgDark, .bg, .bgLight],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: Theme.largeSpacing) {
                    Spacer()
                        .frame(height: 60)
                    
                    // Logo and title
                    VStack(spacing: 20) {
                        // Logo with brand colors
                        ZStack {
                            Circle()
                                .fill(Color(hue: 247/360, saturation: 0.33, brightness: 0.06))
                                .frame(width: 120, height: 120)
                            
                            Image(systemName: "waveform")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 60, height: 60)
                                .foregroundStyle(Color(hue: 49/360, saturation: 1.0, brightness: 0.55))
                        }
                        
                        Text("Eloquence")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.textPrimary)
                        
                        Text("Master the art of communication")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.textMuted)
                    }
                    .padding(.bottom, 40)
                    
                    // Login form
                    VStack(spacing: Theme.spacing) {
                        // Email field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.textMuted)
                            
                            HStack {
                                Image(systemName: "envelope.fill")
                                    .foregroundStyle(Color.textMuted)
                                
                                TextField("your@email.com", text: $email)
                                    .textContentType(.emailAddress)
                                    .autocapitalization(.none)
                                    .keyboardType(.emailAddress)
                                    .focused($focusedField, equals: .email)
                                    .foregroundStyle(Color.textPrimary)
                                    .submitLabel(.next)
                                    .onSubmit {
                                        focusedField = .password
                                    }
                            }
                            .padding()
                            .background(Color.bgLight)
                            .cornerRadius(Theme.smallCornerRadius)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.smallCornerRadius)
                                    .stroke(focusedField == .email ? Color.primary : Color.border, lineWidth: 1)
                            )
                        }
                        
                        // Password field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.textMuted)
                            
                            HStack {
                                Image(systemName: "lock.fill")
                                    .foregroundStyle(Color.textMuted)
                                
                                if showPassword {
                                    TextField("Password", text: $password)
                                        .textContentType(.password)
                                        .focused($focusedField, equals: .password)
                                        .foregroundStyle(Color.textPrimary)
                                        .submitLabel(.go)
                                        .onSubmit(handleLogin)
                                } else {
                                    SecureField("Password", text: $password)
                                        .textContentType(.password)
                                        .focused($focusedField, equals: .password)
                                        .foregroundStyle(Color.textPrimary)
                                        .submitLabel(.go)
                                        .onSubmit(handleLogin)
                                }
                                
                                Button(action: { showPassword.toggle() }) {
                                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                        .foregroundStyle(Color.textMuted)
                                }
                            }
                            .padding()
                            .background(Color.bgLight)
                            .cornerRadius(Theme.smallCornerRadius)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.smallCornerRadius)
                                    .stroke(focusedField == .password ? .primary : Color.border, lineWidth: 1)
                            )
                        }
                        
                        // Forgot password
                        HStack {
                            Spacer()
                            Button("Forgot Password?") {
                                // Handle forgot password
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.primary)
                        }
                    }
                    .padding(.horizontal, Theme.largeSpacing)
                    
                    // Login button
                    Button(action: handleLogin) {
                        HStack {
                            Text("Login")
                                .font(.system(size: 18, weight: .semibold))
                            
                            Image(systemName: "arrow.right")
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: Theme.buttonHeight)
                        .foregroundStyle(Color.bg)
                        .background(Color.primary)
                        .cornerRadius(Theme.cornerRadius)
                    }
                    .padding(.horizontal, Theme.largeSpacing)
                    .padding(.top, Theme.spacing)
                    
                    // Sign up
                    HStack(spacing: 4) {
                        Text("Don't have an account?")
                            .foregroundStyle(Color.textMuted)
                        
                        Button("Sign Up") {
                            // Handle sign up
                        }
                        .foregroundStyle(.primary)
                        .fontWeight(.semibold)
                    }
                    .font(.system(size: 15))
                    
                    Spacer()
                }
            }
        }
    }
    
    private func handleLogin() {
        // Prototype: any input goes directly to dashboard
        withAnimation(.spring()) {
            userSession.login(email: email.isEmpty ? "user@eloquence.com" : email, password: "demo")
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(UserSession())
}

