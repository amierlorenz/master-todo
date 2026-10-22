import Foundation
import Security

/// Stores one secret string in the Keychain, such as an API token.
///
/// Secrets live only here: never in source, `UserDefaults`, SwiftData, or logs.
public struct KeychainStore: Sendable {
    public let service: String
    public let account: String
    /// Syncs through iCloud Keychain so the iPhone gets the same secret.
    public let isSynchronizable: Bool
    /// The modern keychain; requires a signed app, so unsigned test runs turn it off.
    public let usesDataProtectionKeychain: Bool

    public init(service: String, account: String, isSynchronizable: Bool = true, usesDataProtectionKeychain: Bool = true) {
        self.service = service
        self.account = account
        self.isSynchronizable = isSynchronizable && usesDataProtectionKeychain
        self.usesDataProtectionKeychain = usesDataProtectionKeychain
    }

    /// The store for the Canvas access token.
    public static let canvasToken = KeychainStore(service: "com.mieracle.MasterToDo.canvas", account: "accessToken")

    public struct KeychainError: Error, Equatable {
        public let status: OSStatus
    }

    public func read() throws -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            return (item as? Data).map { String(decoding: $0, as: UTF8.self) }
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError(status: status)
        }
    }

    public func save(_ value: String) throws {
        let data = Data(value.utf8)
        let status = SecItemUpdate(baseQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = baseQuery
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            let addStatus = SecItemAdd(item as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainError(status: addStatus) }
        } else if status != errSecSuccess {
            throw KeychainError(status: status)
        }
    }

    public func delete() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError(status: status) }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: isSynchronizable ? kCFBooleanTrue! : kCFBooleanFalse!,
            kSecUseDataProtectionKeychain as String: usesDataProtectionKeychain,
        ]
    }
}
