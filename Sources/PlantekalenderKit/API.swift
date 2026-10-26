import Foundation

// The slice of the Plantekalender API the app uses, one protocol per area, so a view model
// depends on only what it calls and a test fakes only that.

public protocol AuthAPI: Sendable {
    func login(email: String, password: String) async throws -> AuthResponse
    func register(email: String, password: String) async throws -> AuthResponse
    func logout() async throws
}

public protocol GardenAPI: Sendable {
    func gardens() async throws -> [Garden]
    func createGarden(name: String) async throws -> Garden
    func areas(gardenId: String) async throws -> [Area]
    func items(gardenId: String) async throws -> [Item]
    func addItem(gardenId: String, item: NewItem) async throws -> Item
    func plants() async throws -> [PlantSummary]
}

public protocol BoardAPI: Sendable {
    func board(gardenId: String) async throws -> [BoardTask]
    func setTaskState(gardenId: String, key: String, status: String, snoozedUntil: String?) async throws
    func reopenTask(gardenId: String, key: String) async throws
    func alerts(gardenId: String) async throws -> [FrostAlert]
}

public protocol HarvestAPI: Sendable {
    func harvests(gardenId: String, year: Int) async throws -> [Harvest]
    func addHarvest(gardenId: String, harvest: NewHarvest) async throws -> Harvest
    func deleteHarvest(gardenId: String, harvestId: String) async throws
}

public typealias PlantekalenderAPI = AuthAPI & GardenAPI & BoardAPI & HarvestAPI

/// An error response from the API; `code` is the `error` field, e.g. `invalid_credentials`.
public struct APIError: Error, Equatable {
    public let status: Int
    public let code: String

    public init(status: Int, code: String) {
        self.status = status
        self.code = code
    }
}
