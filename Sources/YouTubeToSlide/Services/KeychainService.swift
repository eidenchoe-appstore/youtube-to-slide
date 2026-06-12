import Foundation
import Security

enum KeychainService {
    private static let service = "com.eidenchoe.youtube-to-slide"
    private static let openRouterAccount = "openrouter-api-key"
    private static let notionAccount = "notion-api-key"

    static func saveOpenRouterAPIKey(_ apiKey: String) throws {
        try save(apiKey, account: openRouterAccount)
    }

    static func loadOpenRouterAPIKey() -> String? {
        load(account: openRouterAccount)
    }

    static func deleteOpenRouterAPIKey() throws {
        try delete(account: openRouterAccount)
    }

    static func saveNotionAPIKey(_ apiKey: String) throws {
        try save(apiKey, account: notionAccount)
    }

    static func loadNotionAPIKey() -> String? {
        load(account: notionAccount)
    }

    static func deleteNotionAPIKey() throws {
        try delete(account: notionAccount)
    }

    private static func save(_ value: String, account: String) throws {
        let data = Data(value.utf8)
        let query = baseQuery(account: account)

        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = data

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unhandledStatus(status)
        }
    }

    private static func load(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    private static func delete(account: String) throws {
        let query = baseQuery(account: account)
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledStatus(status)
        }
    }

    private static func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

enum KeychainError: LocalizedError {
    case unhandledStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case let .unhandledStatus(status):
            return "Keychain operation failed with status \(status)."
        }
    }
}
