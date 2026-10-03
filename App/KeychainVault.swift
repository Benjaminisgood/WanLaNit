import Foundation
import Security
import ThaiLearnCore

enum KeychainVault {
    static let service = "WanLaNit.AI"

    static func loadCredentials() -> [AICredential] {
        guard let data = read(account: "credentials") else { return [] }
        return (try? JSONDecoder().decode([AICredential].self, from: data)) ?? []
    }

    static func loadAssignments() -> AIAssignments {
        guard let data = read(account: "assignments") else { return AIAssignments() }
        return (try? JSONDecoder().decode(AIAssignments.self, from: data)) ?? AIAssignments()
    }

    static func save(credentials: [AICredential], assignments: AIAssignments) throws {
        try write(account: "credentials", data: JSONEncoder().encode(credentials))
        try write(account: "assignments", data: JSONEncoder().encode(assignments))
    }

    private static func write(account: String, data: Data) throws {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(base as CFDictionary)
        var query = base
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }

    private static func read(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return data
    }
}

struct KeychainError: Error {
    var status: OSStatus
}

enum TTSCache {
    static func read(_ digest: String) -> Data? {
        guard digest.allSatisfy({ $0.isHexDigit }) else { return nil }
        return try? Data(contentsOf: file(digest))
    }

    static func write(_ digest: String, data: Data) {
        guard digest.allSatisfy({ $0.isHexDigit }) else { return }
        let url = file(digest)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }

    private static func file(_ digest: String) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base
            .appendingPathComponent("WanLaNit/tts-cache", isDirectory: true)
            .appendingPathComponent(digest + ".mp3")
    }
}
