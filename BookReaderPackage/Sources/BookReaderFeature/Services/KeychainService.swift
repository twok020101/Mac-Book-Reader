import Foundation
import Security

public actor KeychainService {
    public static let shared = KeychainService()
    
    public init() {}
    
    public func saveAPIKey(_ key: String) throws {
        let data = key.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.twok.BookReader.gemini",
            kSecValueData as String: data
        ]
        
        // Delete any existing item
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }
    
    public func getAPIKey() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.twok.BookReader.gemini",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecItemNotFound {
            return nil
        }
        
        guard status == errSecSuccess, let data = result as? Data, let key = String(data: data, encoding: .utf8) else {
            throw KeychainError.readFailed(status)
        }
        
        return key
    }
    
    public func deleteAPIKey() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.twok.BookReader.gemini"
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}

public enum KeychainError: Error {
    case saveFailed(OSStatus)
    case readFailed(OSStatus)
    case deleteFailed(OSStatus)
}
