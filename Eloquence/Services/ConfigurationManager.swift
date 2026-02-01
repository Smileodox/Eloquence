//
//  ConfigurationManager.swift
//  Eloquence
//
//  Manages configuration from Config.plist
//

import Foundation

/// Errors that can occur during configuration loading
enum ConfigurationError: Error {
    case missingConfigFile
    case invalidStructure
    case missingRequiredKeys(section: String, keys: [String])
    case placeholderValuesDetected

    var userMessage: String {
        switch self {
        case .missingConfigFile:
            return "Configuration file is missing. Please create Config.plist with your credentials. See Config.plist.example for template."
        case .invalidStructure:
            return "Configuration file structure is invalid. Please check Config.plist format."
        case .missingRequiredKeys(let section, let keys):
            return "Missing required configuration in \(section) section: \(keys.joined(separator: ", "))"
        case .placeholderValuesDetected:
            return "Please update Config.plist with your actual credentials. Current values appear to be placeholders."
        }
    }
}

class ConfigurationManager {
    static let shared: ConfigurationManager = {
        do {
            return try ConfigurationManager()
        } catch let error as ConfigurationError {
            print("⚠️ Configuration Error: \(error.userMessage)")
            fatalError("Unable to load configuration: \(error.userMessage)")
        } catch {
            fatalError("Unexpected configuration error: \(error)")
        }
    }()

    // Azure Auth configuration - this is the backend URL for all API calls
    let azureAuthBaseURL: String

    private init() throws {
        // Load Config.plist
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) else {
            throw ConfigurationError.missingConfigFile
        }

        // MARK: - Azure Auth Configuration
        guard let azureAuthConfig = dict["AzureAuth"] as? [String: String],
              let authURL = azureAuthConfig["BaseURL"] else {
            throw ConfigurationError.missingRequiredKeys(section: "AzureAuth", keys: ["BaseURL"])
        }

        // Validate that placeholders have been replaced
        if authURL.contains("YOUR_") {
            throw ConfigurationError.placeholderValuesDetected
        }

        self.azureAuthBaseURL = authURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
