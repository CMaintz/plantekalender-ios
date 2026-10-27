import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
import XCTest
@testable import PlantekalenderKit

/// Records requests and answers each with a canned status and body.
final class RecordingClient: HTTPClient, @unchecked Sendable {
    private let lock = NSLock()
    private var _requests: [URLRequest] = []
    var replies: [(Int, String)] = []

    var requests: [URLRequest] { lock.withLock { _requests } }

    func send(_ request: URLRequest) async throws -> (Data, Int) {
        lock.withLock {
            _requests.append(request)
            let (status, body) = replies.isEmpty ? (204, "") : replies.removeFirst()
            return (Data(body.utf8), status)
        }
    }
}

final class HTTPAPITests: XCTestCase {
    let client = RecordingClient()

    func api(token: String? = "secret-token") -> HTTPAPI {
        HTTPAPI(baseURL: URL(string: "https://example.test")!, token: { token }, client: client)
    }

    func body(_ index: Int = 0) -> String {
        String(decoding: client.requests[index].httpBody ?? Data(), as: UTF8.self)
    }

    func testAsksForATokenAtLoginSoTheAppWorksWithoutCookies() async throws {
        client.replies = [(200, #"{"user":{"id":"u1","email":"a@b.dk"},"token":"t1"}"#)]
        let auth = try await api().login(email: "a@b.dk", password: "hemmeligt")
        XCTAssertTrue(body().contains(#""wantToken":true"#), body())
        XCTAssertEqual(auth.token, "t1")
    }

    func testSendsTheStoredTokenAsABearerHeader() async throws {
        client.replies = [(200, "[]")]
        _ = try await api().gardens()
        XCTAssertEqual(client.requests[0].value(forHTTPHeaderField: "Authorization"), "Bearer secret-token")
    }

    func testSendsNoAuthorizationHeaderWhenSignedOut() async throws {
        client.replies = [(200, "[]")]
        _ = try await api(token: nil).gardens()
        XCTAssertNil(client.requests[0].value(forHTTPHeaderField: "Authorization"))
    }

    func testReadsABoardWithFieldsThisVersionDoesNotKnow() async throws {
        client.replies = [
            (
                200,
                #"""
                [{"key":"i1:tomat:plant-out:2026","origin":"generated","title":"Udplant tomater",
                  "start":"2026-05-17","end":"2026-06-09","status":"open","bucket":"now","newField":1,
                  "task":{"itemId":"i1","plantId":"tomat","activity":"plant-out","frostSensitive":true}}]
                """#
            )
        ]
        let board = try await api().board(gardenId: "g1")
        XCTAssertEqual(board.map(\.bucket), ["now"])
        XCTAssertEqual(board.first?.task?.plantId, "tomat")
    }

    func testTurnsAnErrorBodyIntoAnErrorCarryingTheAPICode() async {
        client.replies = [(401, #"{"error":"invalid_credentials"}"#)]
        do {
            _ = try await api().login(email: "a@b.dk", password: "forkert")
            XCTFail("expected APIError")
        } catch {
            XCTAssertEqual(error as? APIError, APIError(status: 401, code: "invalid_credentials"))
        }
    }

    func testPercentEncodesTheTaskKeyWhichContainsColons() async throws {
        try await api().setTaskState(gardenId: "g1", key: "i1:tomat:plant-out:2026", status: "done", snoozedUntil: nil)
        XCTAssertEqual(
            client.requests[0].url?.absoluteString,
            "https://example.test/api/gardens/g1/tasks/i1%3Atomat%3Aplant-out%3A2026/state"
        )
    }

    func testLeavesOutAnEmptySnoozeDateInsteadOfSendingNull() async throws {
        try await api().setTaskState(gardenId: "g1", key: "k", status: "done", snoozedUntil: nil)
        XCTAssertEqual(body(), #"{"status":"done"}"#)
    }

    func testReadsAHarvestWhosePlantingWasDeletedWhichComesWithANullItemId() async throws {
        client.replies = [
            (
                200,
                #"""
                [{"id":"h1","itemId":null,"plantId":"kartoffel","areaId":null,
                  "harvestedOn":"2026-07-20","amount":2.5,"unit":"kg","note":null}]
                """#
            )
        ]
        let harvests = try await api().harvests(gardenId: "g1", year: 2026)
        XCTAssertNil(harvests.first?.itemId)
    }

    // The session cookie carries the same secret as the bearer token, and responses hold the user's garden.
    func testKeepsNoCookiesOrCachedResponsesThatOutliveASignOut() {
        let configuration = URLSessionClient().session.configuration
        XCTAssertNil(configuration.httpCookieStorage)
        XCTAssertFalse(configuration.httpShouldSetCookies)
        XCTAssertEqual(configuration.httpCookieAcceptPolicy, .never)
        XCTAssertNil(configuration.urlCache)
    }
}
