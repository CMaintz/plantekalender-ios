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

    /// The token for the HTTP client, which reads it off the main actor.
    @ObservationIgnored let box = TokenBox()

    private let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "dk.cmaintz.plantekalender",
        kSecAttrAccount as String: "session",
    ]

    init() {
        var lookup = query
        lookup[kSecReturnData as String] = true
        var result: AnyObject?
        if SecItemCopyMatching(lookup as CFDictionary, &result) == errSecSuccess, let data = result as? Data {
            token = String(decoding: data, as: UTF8.self)
            // didSet does not run during init, so the box is filled by hand here.
            box.write(token)
        }
    }

    func signIn(token: String) {
        SecItemDelete(query as CFDictionary)
        var item = query
        item[kSecValueData as String] = Data(token.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
        self.token = token
    }

    func signOut() {
        SecItemDelete(query as CFDictionary)
        token = nil
    }
}
