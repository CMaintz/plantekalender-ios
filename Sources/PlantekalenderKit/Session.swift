import Foundation

/// Where the signed-in user's bearer token lives: the Keychain in the app, memory in tests.
/// `signIn` throws when the token cannot be kept, so the user hears about it at login rather than
/// finding themselves signed out at the next launch.
@MainActor
public protocol SessionStore: AnyObject {
    func signIn(token: String) throws
    func signOut()
}

/// The calendar day in Denmark, matching the server's notion of today, `plusDays` later.
/// Days are counted on the Danish calendar, so a week stays a week across a DST change.
public func isoDay(_ date: Date, plusDays: Int = 0) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Copenhagen") ?? .current
    let day = calendar.date(byAdding: .day, value: plusDays, to: date) ?? date
    let c = calendar.dateComponents([.year, .month, .day], from: day)
    return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
}

/// How an operation ended. A cancelled one is neither success nor failure: the screen that started
/// it is gone or has started another, so its caller leaves state alone.
enum Outcome: Equatable {
    case succeeded
    case failed(String)
    case cancelled

    var failure: String? {
        if case .failed(let text) = self { return text }
        return nil
    }
}

@MainActor
func outcome(of operation: () async throws -> Void) async -> Outcome {
    do {
        try await operation()
        return .succeeded
    } catch {
        return isCancellation(error) ? .cancelled : .failed(errorText(error))
    }
}

/// Runs `operation` and returns its failure as Danish text, or nil when it succeeded or was cancelled.
@MainActor
func failure(of operation: () async throws -> Void) async -> String? {
    await outcome(of: operation).failure
}

/// URLSession reports a cancelled task as URLError(.cancelled), not CancellationError.
func isCancellation(_ error: Error) -> Bool {
    error is CancellationError || (error as? URLError)?.code == .cancelled
}

/// Whether a response means the stored session is gone. A 401 on /api/auth is a wrong password,
/// which the login screen explains itself; a 401 for a request sent with an older token says
/// nothing about the session that replaced it.
func sessionExpired(status: Int, path: String, sentToken: String?, currentToken: String?) -> Bool {
    status == 401 && !path.hasPrefix("/api/auth/") && sentToken == currentToken
}

/// A screen that reloads from the server after each change it makes.
@MainActor
protocol Reloading: AnyObject {
    var error: String? { get set }
    func load() async
}

extension Reloading {
    /// Runs `write` and, once it worked, reloads so the screen shows the server's view of the change.
    func writeThenReload(_ write: () async throws -> Void) async {
        error = await failure(of: write)
        if error == nil { await load() }
    }
}

/// Numbers a screen's loads, so a load that finishes after a newer one has started drops its
/// answer instead of overwriting newer state. A class, as `run` changes it across an await.
@MainActor
final class LoadTicket {
    private var latest = 0

    /// Fetches and hands the answer to `apply`, unless a newer load started meanwhile. Returns how
    /// the load ended, or nil when it was cancelled or overtaken: the caller then leaves its state alone.
    func run<T>(_ fetch: @MainActor () async throws -> T, apply: (T) -> Void) async -> Outcome? {
        latest += 1
        let ticket = latest
        let result = await outcome {
            let answer = try await fetch()
            if ticket == latest { apply(answer) }
        }
        return ticket == latest && result != .cancelled ? result : nil
    }
}
