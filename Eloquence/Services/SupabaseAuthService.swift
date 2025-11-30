//
//  SupabaseAuthService.swift
//  Eloquence
//
//  Created by Gemini on 29.11.25.
//

import Foundation

class SupabaseAuthService {
    private let config = ConfigurationManager.shared
    private let session = URLSession.shared
    
    init() {}
    
    // MARK: - Public API
    
    /// Sends a One-Time Password (OTP) to the specified email address.
    func signInWithOTP(email: String) async throws {
        let urlString = "\(config.supabaseURL)/auth/v1/otp"
        guard let url = URL(string: urlString) else {
            throw SupabaseAuthError.invalidURL
        }
        
        let requestBody = SupabaseOTPRequest(email: email, createUser: true)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.addValue("Bearer \(config.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            throw SupabaseAuthError.networkError(error)
        }
        
        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        
        // If successful, Supabase usually returns an empty JSON object {} or similar for OTP request
    }
    
    /// Verifies the OTP token and logs the user in.
    func verifyOTP(email: String, token: String) async throws -> SupabaseUser {
        let urlString = "\(config.supabaseURL)/auth/v1/verify"
        guard let url = URL(string: urlString) else {
            throw SupabaseAuthError.invalidURL
        }
        
        // 'magiclink' is the correct verification type for OTPs sent via signInWithOTP
        let requestBody = SupabaseVerifyRequest(type: "magiclink", email: email, token: token)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.addValue("Bearer \(config.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            throw SupabaseAuthError.networkError(error)
        }
        
        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        
        do {
            let authResponse = try JSONDecoder().decode(SupabaseAuthResponse.self, from: data)
            return authResponse.user
        } catch {
            throw SupabaseAuthError.decodingError(error)
        }
    }
    
    // MARK: - Helper
    
    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseAuthError.unexpectedResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            // Try to decode error message
            if let errorResponse = try? JSONDecoder().decode(SupabaseErrorResponse.self, from: data) {
                throw SupabaseAuthError.apiError(code: httpResponse.statusCode, message: errorResponse.message)
            }
            throw SupabaseAuthError.apiError(code: httpResponse.statusCode, message: "Status code: \(httpResponse.statusCode)")
        }
    }
}
