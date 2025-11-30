//
//  AzureAuthModels.swift
//  Eloquence
//
//  Models for Azure authentication
//

import Foundation

// MARK: - Errors

enum AzureAuthError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case apiError(code: Int, message: String)
    case unexpectedResponse
    case unauthorized
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid authentication server URL."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .apiError(let code, let message):
            if code == 429 {
                return "Too many requests. Please wait a moment before trying again."
            }
            return "Error (\(code)): \(message)"
        case .unexpectedResponse:
            return "Unexpected response from server."
        case .unauthorized:
            return "Unauthorized access."
        case .rateLimited:
            return "Too many attempts. Please wait before trying again."
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

struct SendOTPRequest: Codable {
    let email: String
}

struct VerifyOTPRequest: Codable {
    let email: String
    let code: String
}

// MARK: - Responses

struct SendOTPResponse: Codable {
    let success: Bool
    let message: String
    let expiresIn: Int
}

struct VerifyOTPResponse: Codable {
    let success: Bool
    let message: String
    let user: User?
    let accessToken: String?
    let expiresIn: Int?
}

struct User: Codable {
    let id: String
    let email: String
    let createdAt: String
    let lastLoginAt: String
}

struct AuthenticatedUser {
    let user: User
    let accessToken: String
    let expiresIn: Int
}

// Error response format
struct ErrorResponse: Codable {
    let error: String?
    let message: String
    let code: Int
}
