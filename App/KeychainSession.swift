import Foundation
import Observation
import PlantekalenderKit
import Security

/// Keeps the session token in the Keychain, readable only on this device while it is unlocked,
/// so it never lands in a backup.
@MainActor
@Observable
final class KeychainSession: SessionStore {
    private(set) var token: String? {
        didSet { box.write(token) }
    }

    /// The Keychain could not be read, which is not the same as holding no token: a launch before
    /// the device's first unlock gets errSecInteractionNotAllowed, and must not look signed out.
    private(set) var unreadable = false

    /// The token for the HTTP client, which reads it off the main actor.
    @ObservationIgnored let box = TokenBox()

    private let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "dk.cmaintz.plantekalender",
        kSecAttrAccount as String: "session",
    ]

    init() {
        read()
    }

    func read() {
        var lookup = query
        lookup[kSecReturnData as String] = true
        var result: AnyObject?
        let status = SecItemCopyMatching(lookup as CFDictionary, &result)
        unreadable = status != errSecSuccess && status != errSecItemNotFound
        token = (result as? Data).map { String(decoding: $0, as: UTF8.self) }
        // Written directly as well: this runs from init, where didSet cannot be relied on.
        box.write(token)
    }

    func signIn(token: String) throws {
        try save(Data(token.utf8))
        self.token = token
    }

    func signOut() {
        SecItemDelete(query as CFDictionary)
        token = nil
    }

    /// Updates the stored token in place, or adds it when there is none, so a failed save never
    /// leaves the user with no token at all.
    private func save(_ data: Data) throws {
        var status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            status = SecItemAdd(item as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }
}

struct KeychainError: Error {
    let status: OSStatus
}
