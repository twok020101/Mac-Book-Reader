import Foundation
import GoogleGenerativeAI

@MainActor
public class GeminiService: ObservableObject {
    public static let shared = GeminiService()
    
    @Published public var isConfigured: Bool = false
    private var model: GenerativeModel?
    private let keychainService = KeychainService.shared
    
    private init() {
        Task {
            if let key = try? await keychainService.getAPIKey() {
                self.configure(apiKey: key)
            }
        }
    }
    
    public func configure(apiKey: String) {
        // Save to keychain if new
        Task {
            try? await keychainService.saveAPIKey(apiKey)
        }
        self.model = GenerativeModel(name: "gemini-pro", apiKey: apiKey)
        self.isConfigured = true
    }
    
    public func generateContent(prompt: String) async throws -> String {
        guard let model = model else {
            throw GeminiError.notConfigured
        }
        
        let response = try await model.generateContent(prompt)
        return response.text ?? "No response"
    }
    
    public func getApiKey() async -> String? {
        return try? await keychainService.getAPIKey()
    }
    
    public func clearKey() {
        Task {
            try? await keychainService.deleteAPIKey()
        }
        self.model = nil
        self.isConfigured = false
    }
}

public enum GeminiError: Error {
    case notConfigured
}
