import Foundation
import Observation

/// A bed with its plantings; `area` is nil for plantings that are not in any bed.
public struct AreaGroup: Equatable, Identifiable {
    public let area: Area?
    public let items: [Item]
    public var id: String { area?.id ?? "loose" }
}

func groupByArea(_ areas: [Area], _ items: [Item]) -> [AreaGroup] {
    let beds = areas.map { area in AreaGroup(area: area, items: items.filter { $0.areaId == area.id }) }
    let known = Set(areas.map(\.id))
    let loose = items.filter { $0.areaId.map { !known.contains($0) } ?? true }
    return loose.isEmpty ? beds : beds + [AreaGroup(area: nil, items: loose)]
}

@MainActor
@Observable
public final class GardenModel {
    public private(set) var loading = true
    public private(set) var groups: [AreaGroup] = []
    public private(set) var plants: [PlantSummary] = []
    public private(set) var error: String?
    /// A load has worked, so empty lists mean there is nothing rather than that loading failed.
    public private(set) var loaded = false

    private var tickets = LoadTicket()
    private let api: GardenAPI
    private let gardenId: String

    public init(api: GardenAPI, gardenId: String) {
        self.api = api
        self.gardenId = gardenId
    }

    public func load() async {
        let ticket = tickets.next()
        let result = await outcome {
            let groups = groupByArea(try await api.areas(gardenId: gardenId), try await api.items(gardenId: gardenId))
            let plants = plants.isEmpty ? try await api.plants() : plants
            guard tickets.isCurrent(ticket) else { return }
            self.groups = groups
            self.plants = plants
            loaded = true
        }
        guard tickets.isCurrent(ticket), result != .cancelled else { return }
        error = result.failure
        loading = false
    }

    public func plant(_ plantId: String, in areaId: String?) async {
        error = await failure {
            _ = try await api.addItem(
                gardenId: gardenId, item: NewItem(plantId: plantId, status: "active", areaId: areaId))
        }
        if error == nil { await load() }
    }
}
