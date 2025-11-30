//
//  ConfigurationManager.swift
//  Eloquence
//
//  Manages Azure OpenAI configuration from Config.plist
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
            return "Configuration file is missing. Please create Config.plist with your Azure OpenAI credentials. See Config.plist.example for template."
        case .invalidStructure:
            return "Configuration file structure is invalid. Please check Config.plist format."
        case .missingRequiredKeys(let section, let keys):
            return "Missing required configuration in \(section) section: \(keys.joined(separator: ", "))"
        case .placeholderValuesDetected:
            return "Please update Config.plist with your actual Azure OpenAI credentials. Current values appear to be placeholders."
        }
    }
}

class ConfigurationManager {
    static let shared: ConfigurationManager = {
        do {
            return try ConfigurationManager()
        } catch let error as ConfigurationError {
            // In production, you might want to log this error
            print("⚠️ Configuration Error: \(error.userMessage)")
            // Return a default instance that will cause errors when used
            // The app should check for valid configuration before using services
            fatalError("Unable to load configuration: \(error.userMessage)")
        } catch {
            fatalError("Unexpected configuration error: \(error)")
        }
    }()

    let azureAPIKey: String
    let baseEndpoint: String

    // Whisper configuration
    let whisperDeployment: String
    let whisperAPIVersion: String

    // GPT configuration
    let gptDeployment: String
    let gptAPIVersion: String

    // Supabase configuration
    let supabaseURL: String
    let supabaseAnonKey: String

    // Azure Auth configuration
    let azureAuthBaseURL: String

    private init() throws {
        // Load Config.plist
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) else {
            throw ConfigurationError.missingConfigFile
        }

        // MARK: - Azure OpenAI Configuration
        // Get Azure OpenAI section
        guard let azureConfig = dict["AzureOpenAI"] as? [String: Any] else {
            throw ConfigurationError.invalidStructure
        }

        // Read top-level keys
        guard let apiKey = azureConfig["APIKey"] as? String,
              let endpoint = azureConfig["BaseEndpoint"] as? String else {
            throw ConfigurationError.missingRequiredKeys(
                section: "AzureOpenAI",
                keys: ["APIKey", "BaseEndpoint"]
            )
        }

        guard let whisperConfig = azureConfig["Whisper"] as? [String: String],
              let gptConfig = azureConfig["GPT"] as? [String: String] else {
            throw ConfigurationError.missingRequiredKeys(
                section: "AzureOpenAI",
                keys: ["Whisper (dict)", "GPT (dict)"]
            )
        }

        // Read Whisper configuration
        guard let whisperDeployment = whisperConfig["DeploymentName"],
              let whisperAPIVersion = whisperConfig["APIVersion"] else {
            throw ConfigurationError.missingRequiredKeys(
                section: "Whisper",
                keys: ["DeploymentName", "APIVersion"]
            )
        }

        // Read GPT configuration
        guard let gptDeployment = gptConfig["DeploymentName"],
              let gptAPIVersion = gptConfig["APIVersion"] else {
            throw ConfigurationError.missingRequiredKeys(
                section: "GPT",
                keys: ["DeploymentName", "APIVersion"]
            )
        }

        // MARK: - Supabase Configuration
        guard let supabaseConfig = dict["Supabase"] as? [String: String],
              let sbURL = supabaseConfig["URL"],
              let sbKey = supabaseConfig["AnonKey"] else {
             throw ConfigurationError.missingRequiredKeys(section: "Supabase", keys: ["URL", "AnonKey"])
        }

        self.supabaseURL = sbURL
        self.supabaseAnonKey = sbKey

        // MARK: - Azure Auth Configuration
        guard let azureAuthConfig = dict["AzureAuth"] as? [String: String],
              let authURL = azureAuthConfig["BaseURL"] else {
            throw ConfigurationError.missingRequiredKeys(section: "AzureAuth", keys: ["BaseURL"])
        }

        // Validate that placeholders have been replaced
        if apiKey.contains("YOUR_") || endpoint.contains("YOUR_") || authURL.contains("YOUR_") {
            throw ConfigurationError.placeholderValuesDetected
        }

        self.azureAuthBaseURL = authURL.trimmingCharacters(in: .whitespacesAndNewlines)

        self.azureAPIKey = apiKey
        self.baseEndpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        self.whisperDeployment = whisperDeployment
        self.whisperAPIVersion = whisperAPIVersion
        self.gptDeployment = gptDeployment
        self.gptAPIVersion = gptAPIVersion
    }

    /// Builds the complete Whisper API URL
    func whisperURL() -> String {
        return "\(baseEndpoint)/openai/deployments/\(whisperDeployment)/audio/transcriptions?api-version=\(whisperAPIVersion)"
    }

    /// Builds the complete GPT API URL
        func gptURL() -> String {
            return "\(baseEndpoint)/openai/deployments/\(gptDeployment)/chat/completions?api-version=\(gptAPIVersion)"
        }

    /// Validates that the endpoint is properly formatted
    var isEndpointValid: Bool {
        return baseEndpoint.starts(with: "https://") && baseEndpoint.contains(".cognitiveservices.azure.com")
    }
}
