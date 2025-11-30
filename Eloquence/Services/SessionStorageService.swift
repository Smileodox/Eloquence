//
//  SessionStorageService.swift
//  Eloquence
//
//  Service for persisting authentication sessions in UserDefaults
//

import Foundation

class SessionStorageService {
    static let shared = SessionStorageService()

    private let defaults = UserDefaults.standard
    private let sessionKey = "userSession"

    private init() {}

    // MARK: - Session Storage

    struct StoredSession: Codable {
        let userId: String
        let email: String
        let accessToken: String
        let expiresAt: Date
        let lastLoginAt: Date
    }

    func saveSession(user: User, accessToken: String, expiresIn: Int) {
        let expiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))

        let session = StoredSession(
            userId: user.id,
            email: user.email,
            accessToken: accessToken,
            expiresAt: expiresAt,
            lastLoginAt: Date()
        )

        if let encoded = try? JSONEncoder().encode(session) {
            defaults.set(encoded, forKey: sessionKey)
            print("✅ Session saved for user: \(user.email)")
        }
    }

    func loadSession() -> StoredSession? {
        guard let data = defaults.data(forKey: sessionKey),
              let session = try? JSONDecoder().decode(StoredSession.self, from: data) else {
            return nil
        }

        // Check if session is expired
        if session.expiresAt < Date() {
            print("⚠️ Session expired, removing...")
            clearSession()
            return nil
        }

        print("✅ Loaded valid session for user: \(session.email)")
        return session
    }

    func clearSession() {
        defaults.removeObject(forKey: sessionKey)
        print("🗑️ Session cleared")
    }

    var isSessionValid: Bool {
        return loadSession() != nil
    }
}
