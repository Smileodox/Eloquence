//
//  AzureAuthService.swift
//  Eloquence
//
//  Azure Communication Services authentication service
//

import Foundation

class AzureAuthService {
    private let config = ConfigurationManager.shared
    private let session = URLSession.shared

    init() {}

    // MARK: - Public API

    /// Sends a One-Time Password (OTP) to the specified email address.
    func sendOTP(email: String) async throws {
        let urlString = "\(config.azureAuthBaseURL)/auth/send-otp"
        guard let url = URL(string: urlString) else {
            throw AzureAuthError.invalidURL
        }

        let requestBody = SendOTPRequest(email: email)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            throw AzureAuthError.networkError(error)
        }

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)

        // Decode response to check success
        let otpResponse = try JSONDecoder().decode(SendOTPResponse.self, from: data)
        if !otpResponse.success {
            throw AzureAuthError.apiError(code: 400, message: otpResponse.message)
        }
    }

    /// Verifies the OTP token and logs the user in.
    func verifyOTP(email: String, code: String) async throws -> AuthenticatedUser {
        let urlString = "\(config.azureAuthBaseURL)/auth/verify-otp"
        guard let url = URL(string: urlString) else {
            throw AzureAuthError.invalidURL
        }

        let requestBody = VerifyOTPRequest(email: email, code: code)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            throw AzureAuthError.networkError(error)
        }

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)

        do {
            let verifyResponse = try JSONDecoder().decode(VerifyOTPResponse.self, from: data)

            guard verifyResponse.success,
                  let user = verifyResponse.user,
                  let accessToken = verifyResponse.accessToken else {
                throw AzureAuthError.apiError(code: 400, message: "Invalid response from server")
            }

            return AuthenticatedUser(
                user: user,
                accessToken: accessToken,
                expiresIn: verifyResponse.expiresIn ?? 0
            )
        } catch {
            throw AzureAuthError.decodingError(error)
        }
    }

    // MARK: - Helper

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AzureAuthError.unexpectedResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            // Try to decode error message
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw AzureAuthError.apiError(code: httpResponse.statusCode, message: errorResponse.message)
            }
            throw AzureAuthError.apiError(code: httpResponse.statusCode, message: "Status code: \(httpResponse.statusCode)")
        }
    }
}
