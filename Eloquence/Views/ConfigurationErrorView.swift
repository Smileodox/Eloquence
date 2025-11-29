//
//  ConfigurationErrorView.swift
//  Eloquence
//
//  Displays user-friendly configuration errors
//

import SwiftUI

struct ConfigurationErrorView: View {
    let error: ConfigurationError

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Error Icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundColor(.orange)

            // Title
            Text("Configuration Required")
                .font(.title)
                .fontWeight(.bold)

            // Error Message
            Text(error.userMessage)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 32)

            // Instructions based on error type
            VStack(alignment: .leading, spacing: 12) {
                Text("Next Steps:")
                    .font(.headline)
                    .fontWeight(.semibold)

                switch error {
                case .missingConfigFile:
                    instructionItem("1. Create a file named 'Config.plist' in the Eloquence project folder")
                    instructionItem("2. Copy the template from 'Config.plist.example'")
                    instructionItem("3. Add your Azure OpenAI credentials")
                    instructionItem("4. Restart the app")

                case .invalidStructure:
                    instructionItem("1. Check that Config.plist follows the correct format")
                    instructionItem("2. Compare with Config.plist.example")
                    instructionItem("3. Ensure all required sections exist")
                    instructionItem("4. Restart the app after fixing")

                case .missingRequiredKeys(let section, let keys):
                    instructionItem("1. Open Config.plist")
                    instructionItem("2. Add missing keys in '\(section)' section:")
                    ForEach(keys, id: \.self) { key in
                        Text("   • \(key)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 32)
                    }
                    instructionItem("3. Restart the app")

                case .placeholderValuesDetected:
                    instructionItem("1. Open Config.plist")
                    instructionItem("2. Replace placeholder values (YOUR_*) with actual credentials")
                    instructionItem("3. Get credentials from Azure Portal → Azure OpenAI resource")
                    instructionItem("4. Restart the app")
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 16)

            Spacer()

            // Footer
            HStack(spacing: 4) {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                Text("See")
                Link("Azure OpenAI documentation", destination: URL(string: "https://learn.microsoft.com/en-us/azure/ai-services/openai/")!)
                Text("for help")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    @ViewBuilder
    private func instructionItem(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle")
                .foregroundColor(.green)
                .font(.caption)
                .padding(.top, 2)
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// Preview
#Preview {
    ConfigurationErrorView(error: .missingConfigFile)
}

#Preview("Missing Keys") {
    ConfigurationErrorView(error: .missingRequiredKeys(section: "Whisper", keys: ["DeploymentName", "APIVersion"]))
}

#Preview("Placeholders") {
    ConfigurationErrorView(error: .placeholderValuesDetected)
}
