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

final class TokenBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value: String?

    func write(_ token: String?) { lock.withLock { value = token } }
    @Sendable func read() -> String? { lock.withLock { value } }
}

/// Signs out when the server says the current session is gone; see `sessionExpired`.
struct SessionAwareClient: HTTPClient {
    let inner: HTTPClient
    let currentToken: @Sendable () -> String?
    let onExpired: @Sendable () -> Void

    func send(_ request: URLRequest) async throws -> (Data, Int) {
        let (data, status) = try await inner.send(request)
        let sent = request.value(forHTTPHeaderField: "Authorization")?.replacingOccurrences(of: "Bearer ", with: "")
        let path = request.url?.path ?? ""
        if sessionExpired(status: status, path: path, sentToken: sent, currentToken: currentToken()) { onExpired() }
        return (data, status)
    }
}
