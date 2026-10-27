import Foundation
import XCTest
@testable import PlantekalenderKit

final class SignOutCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var _count = 0

    var count: Int { lock.withLock { _count } }
    @Sendable func signOut() { lock.withLock { _count += 1 } }
}

final class SessionAwareClientTests: XCTestCase {
    let server = RecordingClient()
    let signOuts = SignOutCounter()

    /// The API as the app wires it, sending `sent` while the app's current token is `current`.
    func api(base: String = "https://example.test", sent: String = "t1", current: String = "t1") -> HTTPAPI {
        let url = URL(string: base)!
        let client = SessionAwareClient(
            inner: server, baseURL: url, currentToken: { current }, onExpired: signOuts.signOut)
        server.replies = [(401, #"{"error":"unauthenticated"}"#)]
        return HTTPAPI(baseURL: url, token: { sent }, client: client)
    }

    func testSignsOutWhenTheServerRejectsTheCurrentToken() async {
        _ = try? await api().gardens()
        XCTAssertEqual(signOuts.count, 1)
    }

    func testStaysSignedInWhenARequestWithAnOlderTokenIsRejected() async {
        _ = try? await api(sent: "old", current: "new").gardens()
        XCTAssertEqual(signOuts.count, 0)
    }

    func testTreatsARejectedLoginAsAWrongPasswordNotAnExpiredSession() async {
        _ = try? await api().login(email: "a@b.dk", password: "forkert")
        XCTAssertEqual(signOuts.count, 0)
    }

    func testTellsAuthFromOtherPathsUnderABaseURLWithAPathPrefix() async {
        let base = "https://example.test/plantekalender"
        _ = try? await api(base: base).login(email: "a@b.dk", password: "forkert")
        XCTAssertEqual(signOuts.count, 0)
        _ = try? await api(base: base).gardens()
        XCTAssertEqual(signOuts.count, 1)
    }
}
