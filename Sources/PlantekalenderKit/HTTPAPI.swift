import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Sends one request. URLSession in the app; a fake in tests, so the client is tested without a server.
public protocol HTTPClient: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, Int)
}

/// The API over HTTP. `token` is read on every request, so signing in or out takes effect at once.
public struct HTTPAPI: PlantekalenderAPI {
    let baseURL: URL
    let token: @Sendable () -> String?
    let client: HTTPClient

    public init(baseURL: URL, token: @escaping @Sendable () -> String?, client: HTTPClient) {
        self.baseURL = baseURL
        self.token = token
        self.client = client
    }

    func request(_ method: String, _ path: String, body: (some Encodable)? = String?.none) throws -> URLRequest {
        guard let url = URL(string: baseURL.absoluteString + path) else { throw APIError(status: 0, code: "bad_url") }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = token() { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body {
            request.httpBody = try JSONEncoder().encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    func data(_ request: URLRequest) async throws -> Data {
        let (data, status) = try await client.send(request)
        guard (200..<300).contains(status) else {
            let code = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error ?? "unknown"
            throw APIError(status: status, code: code)
        }
        return data
    }

    func get<T: Decodable>(_ path: String) async throws -> T {
        try JSONDecoder().decode(T.self, from: try await data(request("GET", path)))
    }

    func send<T: Decodable>(_ method: String, _ path: String, _ body: some Encodable) async throws -> T {
        try JSONDecoder().decode(T.self, from: try await data(request(method, path, body: body)))
    }

    func call(_ method: String, _ path: String, _ body: (some Encodable)? = String?.none) async throws {
        _ = try await data(request(method, path, body: body))
    }
}

extension HTTPAPI {
    public func login(email: String, password: String) async throws -> AuthResponse {
        try await send("POST", "/api/auth/login", Credentials(email: email, password: password, wantToken: true))
    }

    public func register(email: String, password: String) async throws -> AuthResponse {
        try await send("POST", "/api/auth/register", Credentials(email: email, password: password, wantToken: true))
    }

    public func logout() async throws {
        try await call("POST", "/api/auth/logout", [String: String]())
    }

    public func gardens() async throws -> [Garden] { try await get("/api/gardens") }

    public func createGarden(name: String) async throws -> Garden {
        try await send("POST", "/api/gardens", NewGarden(name: name))
    }

    public func areas(gardenId: String) async throws -> [Area] { try await get("/api/gardens/\(gardenId)/areas") }

    public func items(gardenId: String) async throws -> [Item] { try await get("/api/gardens/\(gardenId)/items") }

    public func addItem(gardenId: String, item: NewItem) async throws -> Item {
        try await send("POST", "/api/gardens/\(gardenId)/items", item)
    }

    public func plants() async throws -> [PlantSummary] { try await get("/api/catalog/plants") }
}

extension HTTPAPI {
    public func board(gardenId: String) async throws -> [BoardTask] { try await get("/api/gardens/\(gardenId)/board") }

    public func setTaskState(gardenId: String, key: String, status: String, snoozedUntil: String?) async throws {
        try await call("PUT", statePath(gardenId, key), TaskStateInput(status: status, snoozedUntil: snoozedUntil))
    }

    public func reopenTask(gardenId: String, key: String) async throws {
        try await call("DELETE", statePath(gardenId, key))
    }

    public func alerts(gardenId: String) async throws -> [FrostAlert] {
        try await get("/api/gardens/\(gardenId)/alerts")
    }

    public func harvests(gardenId: String, year: Int) async throws -> [Harvest] {
        try await get("/api/gardens/\(gardenId)/harvests?year=\(year)")
    }

    public func addHarvest(gardenId: String, harvest: NewHarvest) async throws -> Harvest {
        try await send("POST", "/api/gardens/\(gardenId)/harvests", harvest)
    }

    public func deleteHarvest(gardenId: String, harvestId: String) async throws {
        try await call("DELETE", "/api/gardens/\(gardenId)/harvests/\(harvestId)")
    }

    // A task key holds colons, which a path would otherwise carry unencoded.
    private func statePath(_ gardenId: String, _ key: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let encoded = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
        return "/api/gardens/\(gardenId)/tasks/\(encoded)/state"
    }
}

/// URLSession as the app's HTTP client.
public struct URLSessionClient: HTTPClient {
    public init() {}

    public func send(_ request: URLRequest) async throws -> (Data, Int) {
        let (data, response) = try await URLSession.shared.data(for: request)
        return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
    }
}
