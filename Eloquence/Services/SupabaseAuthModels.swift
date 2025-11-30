//
//  SupabaseAuthModels.swift
//  Eloquence
//
//  Created by Gemini on 29.11.25.
//

import Foundation

// MARK: - Errors

enum SupabaseAuthError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case apiError(code: Int, message: String)
    case unexpectedResponse
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Supabase URL configuration."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .apiError(let code, let message):
            return "Supabase Error (\(code)): \(message)"
        case .unexpectedResponse:
            return "Unexpected response from server."
        case .unauthorized:
            return "Unauthorized access. Please check your API key."
        }
    }
    
    var isRetryable: Bool {
        switch self {
        case .networkError, .unexpectedResponse:
            return true
        case .apiError(let code, _):
            // Retry on server errors (5xx) or rate limits (429)
            return code >= 500 || code == 429
        default:
            return false
        }
    }
}

// MARK: - Requests

struct SupabaseOTPRequest: Codable {
    let email: String
    let createUser: Bool
    
    enum CodingKeys: String, CodingKey {
        case email
        case createUser = "create_user"
    }
}

struct SupabaseVerifyRequest: Codable {
    let type: String
    let email: String
    let token: String
}

// MARK: - Responses

struct SupabaseAuthResponse: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let refreshToken: String
    let user: SupabaseUser
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case user
    }
}

struct SupabaseUser: Codable {
    let id: String
    let aud: String
    let role: String
    let email: String?
    let confirmedAt: String?
    let lastSignInAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id, aud, role, email
        case confirmedAt = "confirmed_at"
        case lastSignInAt = "last_sign_in_at"
    }
}

// Error response format from Supabase
struct SupabaseErrorResponse: Codable {
    let code: Int?
    let msg: String?
    let error: String?
    let errorDescription: String?
    
    var message: String {
        return msg ?? errorDescription ?? error ?? "Unknown error"
    }
    
    enum CodingKeys: String, CodingKey {
        case code, msg, error
        case errorDescription = "error_description"
    }
}
