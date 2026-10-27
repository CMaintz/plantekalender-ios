import Foundation
import Observation

/// Logs today's harvest against a planting and lists the year's harvests. A harvest task may pass
/// its planting in, which is chosen even when it is still marked as planned.
@MainActor
@Observable
public final class HarvestModel {
    public private(set) var loading = true
    public private(set) var choices: [Item] = []
    public var itemId: String?
    public var amount = ""
    public var unit = "kg"
    public private(set) var harvests: [Harvest] = []
    public private(set) var busy = false
    public private(set) var error: String?

    private var tickets = LoadTicket()
    private let gardens: GardenAPI
    private let api: HarvestAPI
    private let gardenId: String
    private let preselect: String?
    private let now: @Sendable () -> Date

    public init(
        gardens: GardenAPI, api: HarvestAPI, gardenId: String, preselect: String? = nil,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.gardens = gardens
        self.api = api
        self.gardenId = gardenId
        self.preselect = preselect
        self.now = now
    }

    public func load() async {
        let ticket = tickets.next()
        let result = await outcome {
            let choices = try await gardens.items(gardenId: gardenId).filter {
                $0.status != "planned" || $0.id == preselect
            }
            let harvests = try await api.harvests(gardenId: gardenId, year: year)
            guard tickets.isCurrent(ticket) else { return }
            let kept = itemId.flatMap { id in choices.first { $0.id == id }?.id }
            self.choices = choices
            self.harvests = harvests
            itemId = kept ?? choices.first { $0.id == preselect }?.id ?? choices.first?.id
        }
        guard tickets.isCurrent(ticket), result != .cancelled else { return }
        error = result.failure
        loading = false
    }

    public func submit() async {
        guard let value = parseAmount(amount), let itemId else {
            error = "Skriv en mængde, fx 2,5."
            return
        }
        busy = true
        defer { busy = false }
        let harvest = NewHarvest(itemId: itemId, harvestedOn: isoDay(now()), amount: value, unit: unit)
        error = await failure {
            _ = try await api.addHarvest(gardenId: gardenId, harvest: harvest)
            amount = ""
        }
        if error == nil { await load() }
    }

    public func delete(_ harvest: Harvest) async {
        error = await failure { try await api.deleteHarvest(gardenId: gardenId, harvestId: harvest.id) }
        if error == nil { await load() }
    }

    private var year: Int { Int(isoDay(now()).prefix(4)) ?? 0 }
}
