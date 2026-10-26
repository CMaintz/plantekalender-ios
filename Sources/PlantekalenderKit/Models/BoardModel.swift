import Foundation
import Observation

public struct BoardSection: Equatable, Identifiable {
    public let bucket: String
    public let tasks: [BoardTask]
    public var id: String { bucket }
}

// Most urgent first, as on the web board. A bucket a newer server invents lands in `later`.
let bucketOrder = ["overdue", "now", "week", "month", "season", "later"]
private let finishedBuckets: Set = ["done", "dismissed"]
private let snoozeDays = 7

func sections(_ board: [BoardTask]) -> [BoardSection] {
    let open = board.filter { !finishedBuckets.contains($0.bucket) }
    let byBucket = Dictionary(grouping: open) { bucketOrder.contains($0.bucket) ? $0.bucket : "later" }
    return bucketOrder.compactMap { bucket in byBucket[bucket].map { BoardSection(bucket: bucket, tasks: $0) } }
}

@MainActor
@Observable
public final class BoardModel {
    public private(set) var loading = true
    public private(set) var sections: [BoardSection] = []
    public private(set) var finished: [BoardTask] = []
    public private(set) var alerts: [FrostAlert] = []
    public private(set) var error: String?

    private var tickets = LoadTicket()
    private let api: BoardAPI
    private let gardenId: String
    private let now: @Sendable () -> Date

    public init(api: BoardAPI, gardenId: String, now: @escaping @Sendable () -> Date = Date.init) {
        self.api = api
        self.gardenId = gardenId
        self.now = now
    }

    public func load() async {
        let ticket = tickets.next()
        let failed = await failure {
            let board = try await api.board(gardenId: gardenId)
            // Frost alerts need the weather service; the board is still worth showing without them.
            let alerts = (try? await api.alerts(gardenId: gardenId)) ?? []
            guard tickets.isCurrent(ticket) else { return }
            self.alerts = alerts
            sections = PlantekalenderKit.sections(board)
            finished = board.filter { finishedBuckets.contains($0.bucket) }
        }
        guard tickets.isCurrent(ticket) else { return }
        error = failed
        loading = false
    }

    public func done(_ task: BoardTask) async { await write(task, status: "done") }

    public func snooze(_ task: BoardTask) async {
        await write(task, status: "snoozed", until: isoDay(now(), plusDays: snoozeDays))
    }

    public func dismiss(_ task: BoardTask) async { await write(task, status: "dismissed") }

    public func reopen(_ task: BoardTask) async {
        error = await failure { try await api.reopenTask(gardenId: gardenId, key: task.key) }
        if error == nil { await load() }
    }

    private func write(_ task: BoardTask, status: String, until: String? = nil) async {
        error = await failure {
            try await api.setTaskState(gardenId: gardenId, key: task.key, status: status, snoozedUntil: until)
        }
        if error == nil { await load() }
    }
}
