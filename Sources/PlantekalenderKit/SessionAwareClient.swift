import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// The session token, for an HTTP client that reads it off the main actor.
public final class TokenBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value: String?

    public init() {}

    public func write(_ token: String?) { lock.withLock { value = token } }
    @Sendable public func read() -> String? { lock.withLock { value } }
}

/// Signs out when the server says the current session is gone; see `sessionExpired`.
public struct SessionAwareClient: HTTPClient {
    let inner: HTTPClient
    let currentToken: @Sendable () -> String?
    let onExpired: @Sendable () -> Void

    public init(
        inner: HTTPClient, currentToken: @escaping @Sendable () -> String?, onExpired: @escaping @Sendable () -> Void
    ) {
        self.inner = inner
        self.currentToken = currentToken
        self.onExpired = onExpired
    }

    public func send(_ request: URLRequest) async throws -> (Data, Int) {
        let (data, status) = try await inner.send(request)
        let sent = request.value(forHTTPHeaderField: "Authorization")?.replacingOccurrences(of: "Bearer ", with: "")
        let path = request.url?.path ?? ""
        if sessionExpired(status: status, path: path, sentToken: sent, currentToken: currentToken()) { onExpired() }
        return (data, status)
    }
}
