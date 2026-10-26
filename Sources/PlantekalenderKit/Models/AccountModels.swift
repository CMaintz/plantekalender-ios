import Foundation
import Observation

@MainActor
@Observable
public final class LoginModel {
    public var email = ""
    public var password = ""
    public var registering = false
    public private(set) var busy = false
    public private(set) var error: String?

    private let api: AuthAPI
    private let session: SessionStore

    public init(api: AuthAPI, session: SessionStore) {
        self.api = api
        self.session = session
    }

    public func submit() async {
        busy = true
        defer { busy = false }
        let email = email.trimmingCharacters(in: .whitespaces)
        error = await failure {
            let auth =
                registering
                ? try await api.register(email: email, password: password)
                : try await api.login(email: email, password: password)
            guard let token = auth.token else { throw APIError(status: 0, code: "no_token") }
            session.signIn(token: token)
        }
    }
}

/// The signed-in shell: which garden the tabs show, plant names for every screen, and logout.
@MainActor
@Observable
public final class HomeModel {
    public private(set) var loading = true
    public private(set) var garden: Garden?
    public private(set) var plantNames: [String: String] = [:]
    public private(set) var error: String?
    /// The first load failed, which is not the same as having no garden.
    public private(set) var failed = false

    private let auth: AuthAPI
    private let api: GardenAPI
    private let session: SessionStore

    public init(auth: AuthAPI, api: GardenAPI, session: SessionStore) {
        self.auth = auth
        self.api = api
        self.session = session
    }

    public func load() async {
        loading = true
        error = await failure {
            garden = try await api.gardens().first
            plantNames = Dictionary(try await api.plants().map { ($0.id, $0.name) }) { first, _ in first }
        }
        failed = error != nil
        loading = false
    }

    public func plantName(_ id: String) -> String { plantNames[id] ?? id }

    public func createGarden(named name: String) async {
        error = await failure { garden = try await api.createGarden(name: name.trimmingCharacters(in: .whitespaces)) }
    }

    /// Forgets the token even when the server cannot be reached, so the user is never stuck signed in.
    public func logout() async {
        try? await auth.logout()
        session.signOut()
    }
}
