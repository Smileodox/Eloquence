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
    @State private var otpCode: String = ""
    @FocusState private var focusedField: Field?
    @State private var loginStep: LoginStep = .email
    
    enum LoginStep {
        case email
        case code
    }
    
    enum Field {
        case email, otp
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
                    
                    if loginStep == .email {
                        emailInputView
                            .transition(.move(edge: .leading))
                    } else {
                        otpInputView
                            .transition(.move(edge: .trailing))
                    }
                    
                    // Error Message
                    if let error = userSession.authError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(Color.danger)
                            .padding(.horizontal)
                            .multilineTextAlignment(.center)
                    }
                    
                    Spacer()
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: loginStep)
    }
    
    // MARK: - Step 1: Email Input
    
    var emailInputView: some View {
        VStack(spacing: Theme.spacing) {
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
                        .onSubmit(sendCode)
                }
                .padding()
                .background(Color.bgLight)
                .cornerRadius(Theme.smallCornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.smallCornerRadius)
                        .stroke(focusedField == .email ? Color.primary : Color.border, lineWidth: 1)
                )
            }
            
            Button(action: sendCode) {
                ZStack {
                    if userSession.isSendingCode {
                        SwiftUI.ProgressView()
                            .tint(email.isEmpty ? Color.bg.opacity(0.5) : Color.bg)
                    } else {
                        HStack {
                            Text("Send Login Code")
                                .font(.system(size: 18, weight: .semibold))
                            Image(systemName: "arrow.right")
                        }
                        .foregroundStyle(email.isEmpty ? Color.bg.opacity(0.5) : Color.bg)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: Theme.buttonHeight)
                .background(email.isEmpty ? Color.primary.opacity(0.5) : Color.primary)
                .cornerRadius(Theme.cornerRadius)
            }
            .disabled(email.isEmpty || userSession.isSendingCode)
            .padding(.top, Theme.spacing)
        }
        .padding(.horizontal, Theme.largeSpacing)
        .onAppear {
            focusedField = .email
        }
    }
    
    // MARK: - Step 2: OTP Input
    
    var otpInputView: some View {
        VStack(spacing: Theme.spacing) {
            // Show sending indicator while OTP is being sent
            if userSession.isSendingCode {
                HStack(spacing: 8) {
                    SwiftUI.ProgressView()
                        .scaleEffect(0.8)
                    Text("Sending code...")
                        .font(.caption)
                        .foregroundStyle(Color.textMuted)
                }
                .padding(.bottom, 8)
            }

            Text("Enter the 6-digit code sent to")
                .foregroundStyle(Color.textMuted)
            Text(email)
                .font(.headline)
                .foregroundStyle(Color.textPrimary)
            
            // Custom 6-digit OTP Field
            HStack(spacing: 12) {
                ForEach(0..<6, id: \.self) { index in
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.bgLight)
                            .frame(height: 60)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.border, lineWidth: 1)
                            )
                        
                        if otpCode.count > index {
                            let charIndex = otpCode.index(otpCode.startIndex, offsetBy: index)
                            Text(String(otpCode[charIndex]))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.textPrimary)
                        }
                    }
                }
            }
            .overlay(
                TextField("", text: $otpCode)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .focused($focusedField, equals: .otp)
                    .opacity(0.01) // Invisible but interactive
                    .onChange(of: otpCode) {
                        if otpCode.count > 6 {
                            otpCode = String(otpCode.prefix(6))
                        }
                        if otpCode.count == 6 {
                            verifyCode()
                        }
                    }
            )
            .padding(.vertical, 20)
            
            Button(action: verifyCode) {
                ZStack {
                    if userSession.isVerifyingCode {
                        SwiftUI.ProgressView()
                            .tint(otpCode.count < 6 ? Color.bg.opacity(0.5) : Color.bg)
                    } else {
                        HStack {
                            Text("Verify & Login")
                                .font(.system(size: 18, weight: .semibold))
                            Image(systemName: "checkmark.circle.fill")
                        }
                        .foregroundStyle(otpCode.count < 6 ? Color.bg.opacity(0.5) : Color.bg)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: Theme.buttonHeight)
                .background(otpCode.count < 6 ? Color.primary.opacity(0.5) : Color.primary)
                .cornerRadius(Theme.cornerRadius)
            }
            .disabled(otpCode.count < 6 || userSession.isVerifyingCode)
            
            Button("Send New Code") {
                loginStep = .email
                otpCode = ""
            }
            .font(.subheadline)
            .foregroundStyle(Color.textMuted)
            .padding(.top)
        }
        .padding(.horizontal, Theme.largeSpacing)
        .onAppear {
            focusedField = .otp
        }
    }
    
    // MARK: - Actions
    
    private func sendCode() {
        guard !email.isEmpty else { return }

        // Show PIN screen immediately for better UX
        withAnimation {
            loginStep = .code
        }

        // Send OTP in background
        Task {
            let success = await userSession.sendOTP(email: email)
            if !success {
                // On failure, show error and return to email screen
                withAnimation {
                    loginStep = .email
                }
            }
        }
    }
    
    private func verifyCode() {
        guard otpCode.count == 6 else { return }
        Task {
            _ = await userSession.verifyOTP(code: otpCode)
            // If success, userSession.isLoggedIn becomes true and RootView switches to Dashboard
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(UserSession())
}

