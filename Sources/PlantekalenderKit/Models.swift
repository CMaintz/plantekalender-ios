import Foundation

// The JSON shapes of the Plantekalender API. Enum-like values (status, bucket,
// activity, unit) stay strings: a server that adds a value must not break an app that is not
// updated yet. Optional fields are optional here too, and unknown keys are ignored by Codable.

public struct User: Codable, Sendable, Equatable {
    public let id: String
    public let email: String
}

public struct AuthResponse: Codable, Sendable {
    public let user: User
    public let token: String?
}

struct Credentials: Codable {
    let email: String
    let password: String
    let wantToken: Bool
}

public struct Garden: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
}

struct NewGarden: Codable {
    let name: String
}

public struct Area: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let type: String
}

public struct Item: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let plantId: String
    public let status: String
    public var areaId: String?
    public var variety: String?
    public var season: Int?

    public init(
        id: String, plantId: String, status: String, areaId: String? = nil, variety: String? = nil, season: Int? = nil
    ) {
        self.id = id
        self.plantId = plantId
        self.status = status
        self.areaId = areaId
        self.variety = variety
        self.season = season
    }
}

public struct NewItem: Codable, Sendable, Equatable {
    public let plantId: String
    public let status: String
    public var areaId: String?

    public init(plantId: String, status: String, areaId: String? = nil) {
        self.plantId = plantId
        self.status = status
        self.areaId = areaId
    }
}

public struct PlantSummary: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let kind: String
}

public struct GeneratedTask: Codable, Sendable, Equatable {
    public let itemId: String
    public let plantId: String
    public let activity: String

    public init(itemId: String, plantId: String, activity: String) {
        self.itemId = itemId
        self.plantId = plantId
        self.activity = activity
    }
}

public struct BoardTask: Codable, Sendable, Equatable, Identifiable {
    public let key: String
    public let origin: String
    public let title: String
    public let start: String
    public let end: String
    public let status: String
    public let bucket: String
    public var detail: String?
    public var task: GeneratedTask?

    public var id: String { key }

    public init(
        key: String, origin: String, title: String, start: String, end: String,
        status: String, bucket: String, detail: String? = nil, task: GeneratedTask? = nil
    ) {
        self.key = key
        self.origin = origin
        self.title = title
        self.start = start
        self.end = end
        self.status = status
        self.bucket = bucket
        self.detail = detail
        self.task = task
    }
}

struct TaskStateInput: Codable, Equatable {
    let status: String
    var snoozedUntil: String?
}

public struct FrostAlert: Codable, Sendable, Equatable {
    public let night: String
    public let tmin: Double
    public let severity: String
    public let explanation: String
}

public struct Harvest: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let plantId: String
    public let harvestedOn: String
    public let amount: Double
    public let unit: String
    public var itemId: String?
    public var note: String?

    public init(id: String, plantId: String, harvestedOn: String, amount: Double, unit: String, itemId: String? = nil) {
        self.id = id
        self.plantId = plantId
        self.harvestedOn = harvestedOn
        self.amount = amount
        self.unit = unit
        self.itemId = itemId
    }
}

public struct NewHarvest: Codable, Sendable, Equatable {
    public let itemId: String
    public let harvestedOn: String
    public let amount: Double
    public let unit: String
}

struct ErrorBody: Codable {
    let error: String
}
