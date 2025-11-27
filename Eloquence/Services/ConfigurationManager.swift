//
//  ConfigurationManager.swift
//  Eloquence
//
//  Manages Azure OpenAI configuration from Config.plist
//

import Foundation

class ConfigurationManager {
    static let shared = ConfigurationManager()

    let azureAPIKey: String
    let baseEndpoint: String

    // Whisper configuration
    let whisperDeployment: String
    let whisperAPIVersion: String

    // GPT configuration
    let gptDeployment: String
    let gptAPIVersion: String

    private init() {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path),
              let azureConfig = dict["AzureOpenAI"] as? [String: Any] else {
            fatalError("""
                ⚠️ Config.plist not found or invalid.
                Please create Config.plist in the Eloquence folder with your Azure OpenAI credentials.
                See Config.plist.example for template.
                """)
        }

        // Read top-level keys
        guard let apiKey = azureConfig["APIKey"] as? String,
              let endpoint = azureConfig["BaseEndpoint"] as? String,
              let whisperConfig = azureConfig["Whisper"] as? [String: String],
              let gptConfig = azureConfig["GPT"] as? [String: String] else {
            fatalError("""
                ⚠️ Missing required Azure configuration in Config.plist.
                Required keys: APIKey, BaseEndpoint, Whisper (dict), GPT (dict)
                """)
        }

        // Read Whisper configuration
        guard let whisperDeployment = whisperConfig["DeploymentName"],
              let whisperAPIVersion = whisperConfig["APIVersion"] else {
            fatalError("""
                ⚠️ Missing Whisper configuration in Config.plist.
                Required keys in Whisper section: DeploymentName, APIVersion
                """)
        }

        // Read GPT configuration
        guard let gptDeployment = gptConfig["DeploymentName"],
              let gptAPIVersion = gptConfig["APIVersion"] else {
            fatalError("""
                ⚠️ Missing GPT configuration in Config.plist.
                Required keys in GPT section: DeploymentName, APIVersion
                """)
        }

        // Validate that placeholders have been replaced
        if apiKey.contains("YOUR_") || endpoint.contains("YOUR_") {
            fatalError("""
                ⚠️ Please update Config.plist with your actual Azure OpenAI credentials.
                Current values appear to be placeholders.
                """)
        }

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
