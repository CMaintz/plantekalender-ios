import Foundation
import XCTest
@testable import PlantekalenderKit

/// An in-memory API that records writes, for view model tests.
final class FakeAPI: PlantekalenderAPI, @unchecked Sendable {
    var board: [BoardTask] = []
    var items: [Item] = []
    var harvestList: [Harvest] = []
    var loginError: APIError?
    var offline = false
    /// When set, the next board call waits for it, to test reloads that finish out of order.
    var boardGate: CheckedContinuation<[BoardTask], Never>?
    var holdNextBoard = false
    private(set) var writes: [String] = []

    func login(email: String, password: String) async throws -> AuthResponse {
        if let loginError { throw loginError }
        return AuthResponse(user: User(id: "u1", email: email), token: "token-for-\(email)")
    }

    func register(email: String, password: String) async throws -> AuthResponse {
        writes.append("register \(email)")
        return try await login(email: email, password: password)
    }

    func logout() async throws {
        if offline { throw URLError(.notConnectedToInternet) }
        writes.append("logout")
    }

    func gardens() async throws -> [Garden] {
        if offline { throw URLError(.notConnectedToInternet) }
        return [Garden(id: "g1", name: "Have")]
    }
    func createGarden(name: String) async throws -> Garden { Garden(id: "g2", name: name) }
    func areas(gardenId: String) async throws -> [Area] { [] }
    func items(gardenId: String) async throws -> [Item] { items }

    func addItem(gardenId: String, item: NewItem) async throws -> Item {
        writes.append("item \(item.plantId)")
        return Item(id: "new", plantId: item.plantId, status: item.status)
    }

    func plants() async throws -> [PlantSummary] { [] }
    func board(gardenId: String) async throws -> [BoardTask] {
        guard holdNextBoard else { return board }
        holdNextBoard = false
        return await withCheckedContinuation { boardGate = $0 }
    }

    func setTaskState(gardenId: String, key: String, status: String, snoozedUntil: String?) async throws {
        writes.append(["state", key, status, snoozedUntil].compactMap { $0 }.joined(separator: " "))
    }

    func reopenTask(gardenId: String, key: String) async throws { writes.append("reopen \(key)") }
    func alerts(gardenId: String) async throws -> [FrostAlert] { [] }

    func harvests(gardenId: String, year: Int) async throws -> [Harvest] {
        harvestList.filter { $0.harvestedOn.hasPrefix("\(year)") }
    }

    func addHarvest(gardenId: String, harvest: NewHarvest) async throws -> Harvest {
        writes.append("harvest \(harvest.itemId) \(harvest.amount) \(harvest.unit) \(harvest.harvestedOn)")
        return Harvest(id: "h1", plantId: "kartoffel", harvestedOn: harvest.harvestedOn, amount: harvest.amount, unit: harvest.unit)
    }

    func deleteHarvest(gardenId: String, harvestId: String) async throws { writes.append("delete \(harvestId)") }
}

@MainActor
final class MemorySession: SessionStore {
    var token: String?
    func signIn(token: String) { self.token = token }
    func signOut() { token = nil }
}

// 20 May 2026, 10:00 in Copenhagen.
let may20: @Sendable () -> Date = { Date(timeIntervalSince1970: 1_779_264_000) }

@MainActor
final class ModelTests: XCTestCase {
    let api = FakeAPI()

    func task(_ key: String, _ bucket: String, status: String = "open") -> BoardTask {
        BoardTask(key: key, origin: "generated", title: key, start: "2026-05-01", end: "2026-06-01", status: status, bucket: bucket)
    }

    func testKeepsTheTokenOnceSignedIn() async {
        let session = MemorySession()
        let model = LoginModel(api: api, session: session)
        model.email = " a@b.dk "
        model.password = "hemmeligt"
        await model.submit()
        XCTAssertEqual(session.token, "token-for-a@b.dk")
    }

    func testExplainsAWrongPasswordInDanishAndStaysSignedOut() async {
        api.loginError = APIError(status: 401, code: "invalid_credentials")
        let session = MemorySession()
        let model = LoginModel(api: api, session: session)
        await model.submit()
        XCTAssertEqual(model.error, "Forkert e-mail eller adgangskode.")
        XCTAssertNil(session.token)
    }

    func testListsOpenTasksByUrgencyAndKeepsFinishedOnesApart() async {
        api.board = [task("a", "month"), task("b", "now"), task("c", "done", status: "done"), task("d", "overdue")]
        let model = BoardModel(api: api, gardenId: "g1", now: may20)
        await model.load()
        XCTAssertEqual(model.sections.map(\.bucket), ["overdue", "now", "month"])
        XCTAssertEqual(model.finished.map(\.key), ["c"])
    }

    func testFilesAnUnknownBucketUnderLaterInsteadOfDroppingTheTask() async {
        api.board = [task("a", "someday")]
        let model = BoardModel(api: api, gardenId: "g1", now: may20)
        await model.load()
        XCTAssertEqual(model.sections.map { [$0.bucket] + $0.tasks.map(\.key) }, [["later", "a"]])
    }

    func testSnoozesATaskUntilAWeekFromToday() async {
        let model = BoardModel(api: api, gardenId: "g1", now: may20)
        await model.snooze(task("a", "now"))
        XCTAssertEqual(api.writes, ["state a snoozed 2026-05-27"])
    }

    func testReadsADanishDecimalCommaAndLogsTodaysHarvest() async {
        api.items = [Item(id: "i1", plantId: "kartoffel", status: "active")]
        let model = HarvestModel(gardens: api, api: api, gardenId: "g1", now: may20)
        await model.load()
        model.amount = "2,5"
        await model.submit()
        XCTAssertEqual(api.writes, ["harvest i1 2.5 kg 2026-05-20"])
    }

    func testRefusesAnAmountItCannotReadRatherThanLoggingZero() async {
        api.items = [Item(id: "i1", plantId: "kartoffel", status: "active")]
        let model = HarvestModel(gardens: api, api: api, gardenId: "g1", now: may20)
        await model.load()
        model.amount = "et par"
        await model.submit()
        XCTAssertEqual(api.writes, [])
        XCTAssertEqual(model.error, "Skriv en mængde, fx 2,5.")
    }

    func testChoosesThePlantingAHarvestTaskPointsAtEvenWhenPlanned() async {
        api.items = [Item(id: "i0", plantId: "gulerod", status: "active"), Item(id: "i1", plantId: "tomat", status: "planned")]
        let model = HarvestModel(gardens: api, api: api, gardenId: "g1", preselect: "i1", now: may20)
        await model.load()
        XCTAssertEqual(model.itemId, "i1")
    }

    func testKeepsPlantingsInNoBedOrAGoneBedUnderTheirOwnHeading() {
        let bed = Area(id: "a1", name: "Højbed", type: "raised-bed")
        let items = [
            Item(id: "i1", plantId: "tomat", status: "active", areaId: "a1"),
            Item(id: "i2", plantId: "jordbaer", status: "active"),
            Item(id: "i3", plantId: "kaal", status: "active", areaId: "gone"),
        ]
        let groups = groupByArea([bed], items)
        XCTAssertEqual(groups.map { [$0.area?.name ?? "-"] + $0.items.map(\.id) }, [["Højbed", "i1"], ["-", "i2", "i3"]])
    }

    func testFormatsAmountsTheDanishWay() {
        XCTAssertEqual(amountText(3.25, unit: "kg"), "3,25 kg")
        XCTAssertEqual(amountText(40, unit: "stk"), "40 stk.")
    }

    func testRegistersANewUserInsteadOfLoggingInWhenInRegisterMode() async {
        let model = LoginModel(api: api, session: MemorySession())
        model.registering = true
        model.email = "ny@b.dk"
        await model.submit()
        XCTAssertEqual(api.writes, ["register ny@b.dk"])
    }

    func testSignsOutOnThisDeviceEvenWhenTheServerCannotBeReached() async {
        api.offline = true
        let session = MemorySession()
        session.signIn(token: "t1")
        await HomeModel(auth: api, api: api, session: session).logout()
        XCTAssertNil(session.token)
    }

    func testTellsAFailedFirstLoadApartFromHavingNoGardenAndCanTryAgain() async {
        api.offline = true
        let home = HomeModel(auth: api, api: api, session: MemorySession())
        await home.load()
        XCTAssertTrue(home.failed)
        XCTAssertNil(home.garden)
        api.offline = false
        await home.load()
        XCTAssertEqual(home.garden?.id, "g1")
    }

    func testKeepsTheNewestBoardWhenAnOlderReloadAnswersLast() async {
        api.holdNextBoard = true
        let model = BoardModel(api: api, gardenId: "g1", now: may20)
        let slow = Task { await model.load() }
        while api.boardGate == nil { await Task.yield() }
        api.board = [task("new", "now")]
        await model.load()
        api.boardGate?.resume(returning: [task("old", "now")])
        await slow.value
        XCTAssertEqual(model.sections.flatMap(\.tasks).map(\.key), ["new"])
    }

    func testSignsOutOnlyWhenTheServerRejectsTheCurrentSession() {
        XCTAssertTrue(sessionExpired(status: 401, path: "/api/gardens/g1/board", sentToken: "t1", currentToken: "t1"))
        XCTAssertFalse(sessionExpired(status: 401, path: "/api/auth/login", sentToken: "t1", currentToken: "t1"))
        XCTAssertFalse(sessionExpired(status: 401, path: "/api/gardens", sentToken: "old", currentToken: "new"))
        XCTAssertFalse(sessionExpired(status: 404, path: "/api/gardens/g1", sentToken: "t1", currentToken: "t1"))
    }
}
