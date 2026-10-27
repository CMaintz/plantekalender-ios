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
public final class GardenModel: Reloading {
    public private(set) var loading = true
    public private(set) var groups: [AreaGroup] = []
    public internal(set) var error: String?
    /// A load has worked, so empty lists mean there is nothing rather than that loading failed.
    public private(set) var loaded = false

    private let tickets = LoadTicket()
    private let api: GardenAPI
    private let gardenId: String

    public init(api: GardenAPI, gardenId: String) {
        self.api = api
        self.gardenId = gardenId
    }

    public func load() async {
        let result = await tickets.run {
            groupByArea(try await api.areas(gardenId: gardenId), try await api.items(gardenId: gardenId))
        } apply: { groups in
            self.groups = groups
            loaded = true
        }
        guard let result else { return }
        error = result.failure
        loading = false
    }

    public func plant(_ plantId: String, in areaId: String?) async {
        await writeThenReload {
            _ = try await api.addItem(
                gardenId: gardenId, item: NewItem(plantId: plantId, status: "active", areaId: areaId))
        }
    }
}
