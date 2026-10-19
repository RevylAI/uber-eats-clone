import XCTest
@testable import RidesDemo

final class RideCoreTests: XCTestCase {
    func testDemoFaresUseIntegerCentsAndStopSurcharges() {
        var draft = BookingDraft()
        XCTAssertEqual(draft.fareCents, 1840)
        draft.service = .comfort
        draft.stops = [RideCatalog.places[4]]
        XCTAssertEqual(draft.fareCents, 2790)
        XCTAssertEqual(RideService.uberXL.seats, 6)
    }
    func testRouteRejectsMissingOrDuplicateLocations() {
        var draft = BookingDraft()
        XCTAssertNotNil(draft.validationError())
        draft.destination = draft.pickup
        XCTAssertNotNil(draft.validationError())
        draft.destination = RideCatalog.places[1]
        XCTAssertNil(draft.validationError())
        draft.stops = [draft.pickup]
        XCTAssertNotNil(draft.validationError())
        draft.stops = [RideCatalog.places[4], RideCatalog.places[4]]
        XCTAssertNotNil(draft.validationError())
    }
    func testSchedulingAndNoteValidation() {
        var draft = BookingDraft()
        draft.destination = RideCatalog.places[1]
        let now = Date()
        draft.scheduledAt = now.addingTimeInterval(-1)
        XCTAssertNotNil(draft.validationError(now: now))
        draft.scheduledAt = now.addingTimeInterval(31 * 86400)
        XCTAssertNotNil(draft.validationError(now: now))
        draft.scheduledAt = now.addingTimeInterval(3600)
        XCTAssertNil(draft.validationError(now: now))
        draft.note = String(repeating: "x", count: 301)
        XCTAssertNotNil(draft.validationError(now: now))
    }
    func testBookingEncodesTheSharedServerContract() throws {
        var draft = BookingDraft()
        draft.destination = RideCatalog.places[1]
        draft.payment = .cash
        let request = try TripRequest(draft: draft)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any])
        XCTAssertEqual(json["service"] as? String, "uberX")
        XCTAssertEqual(json["paymentMethod"] as? String, "Demo Cash")
        XCTAssertNotNil(UUID(uuidString: try XCTUnwrap(json["requestId"] as? String)))
        XCTAssertNil(json["token"])
        XCTAssertNil(json["fareCents"])
    }
    func testServerURLRequiresHTTPSWithoutEmbeddedCredentials() throws {
        XCTAssertNoThrow(try RideAPIClient.validatedURL("https://demo.example.com"))
        XCTAssertNoThrow(try RideAPIClient.validatedURL("http://127.0.0.1:8787"))
        for value in ["http://demo.example.com", "https://user:password@demo.example.com", "https://demo.example.com?token=test", "https://demo.example.com/#fragment", "https://demo.example.com/private", "not a url"] {
            XCTAssertThrowsError(try RideAPIClient.validatedURL(value), value)
        }
    }
    func testSearchAndTerminalStateRules() {
        XCTAssertEqual(RideCatalog.search("airport").first?.id, "airport")
        XCTAssertTrue(RideCatalog.search("unlisted location").isEmpty)
        XCTAssertFalse(TripStatus.completed.isActive)
        XCTAssertFalse(TripStatus.cancelled.isActive)
        XCTAssertFalse(TripStatus.inProgress.canCancel)
        XCTAssertTrue(TripStatus.arriving.canCancel)
    }
}

final class RevylRideSignInTests: XCTestCase {
    private let fixture = String(repeating: "fixture-", count: 6)
    private func outcome(_ query: String, enabled: Bool = true, testBuild: Bool = true) -> RevylRideSignIn.Outcome {
        RevylRideSignIn.validate(URL(string: "ridesdemo://revyl-auth?" + query)!, environment: ["RIDES_AUTH_BYPASS_ENABLED": enabled ? "true" : "false", "RIDES_AUTH_BYPASS_TOKEN": fixture], arguments: [], isTestBuild: testBuild)
    }
    func testAllowsOnlyRiderAndDriverWithKnownRoutes() {
        XCTAssertEqual(outcome("token=\(fixture)&role=rider&redirect=/home"), .accepted(.rider, 0))
        XCTAssertEqual(outcome("token=\(fixture)&role=driver&redirect=/activity"), .accepted(.driver, 2))
    }
    func testRejectsWrongTokenDisabledGateAndProduction() {
        XCTAssertEqual(outcome("token=wrong&role=rider&redirect=/home"), .rejected("Invalid session token"))
        XCTAssertEqual(outcome("token=\(fixture)&role=rider&redirect=/home", enabled: false), .rejected("Session gate is disabled"))
        XCTAssertEqual(outcome("token=\(fixture)&role=rider&redirect=/home", testBuild: false), .rejected("Unavailable in production builds"))
    }
    func testRejectsUnknownDuplicateAndExtraParameters() {
        XCTAssertEqual(outcome("token=\(fixture)&role=admin&redirect=/home"), .rejected("Role is not allowed"))
        XCTAssertEqual(outcome("token=\(fixture)&role=rider&redirect=/admin"), .rejected("Redirect is not allowed"))
        XCTAssertEqual(outcome("token=\(fixture)&role=rider&redirect=/home&role=driver"), .rejected("Invalid sign-in parameters"))
        XCTAssertEqual(outcome("token=\(fixture)&role=rider&redirect=/home&extra=x"), .rejected("Invalid sign-in parameters"))
    }
    func testReadsNativeLaunchArgumentPairs() {
        let result = RevylRideSignIn.validate(URL(string: "ridesdemo://revyl-auth?token=\(fixture)&role=driver&redirect=/home")!, environment: [:], arguments: ["RidesDemo", "-RIDES_AUTH_BYPASS_ENABLED", "true", "-RIDES_AUTH_BYPASS_TOKEN", fixture], isTestBuild: true)
        XCTAssertEqual(result, .accepted(.driver, 0))
    }
}

private final class MemoryRideVault: RideSessionVault {
    var value: StoredRideSession?
    func load() -> StoredRideSession? { value }
    func save(_ session: StoredRideSession) { value = session }
    func clear() { value = nil }
}

private final class StubRideAPI: RideAPI {
    let baseURL = URL(string: "https://demo.example.com")!
    var current = RideRoomState(roomCode: "DEMOABCD", revision: 1, driverOnline: false, onlineDriverIds: [], trips: [])
    var failure: Error?
    func create(name: String) async throws -> RideSession { if let failure { throw failure }; return RideSession(roomCode: current.roomCode, participantId: "rider-fixture", token: "test-only-fixture", role: .rider, name: name, state: current) }
    func join(code: String, role: DemoRole, name: String) async throws -> RideSession { if let failure { throw failure }; return RideSession(roomCode: current.roomCode, participantId: "driver-fixture", token: "driver-test-fixture", role: role, name: name, state: current) }
    func state(token: String) async throws -> RideRoomState { if let failure { throw failure }; return current }
    func availability(token: String, online: Bool) async throws -> RideRoomState { current = RideRoomState(roomCode: current.roomCode, revision: current.revision + 1, driverOnline: online, onlineDriverIds: online ? ["driver-fixture"] : [], trips: []); return current }
    func book(token: String, request: TripRequest) async throws -> RideRoomState { current }
    func act(token: String, tripID: String, action: RideAction) async throws -> RideRoomState { current }
}

@MainActor
final class RideStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite: String!
    private var vault: MemoryRideVault!
    private var api: StubRideAPI!
    private var store: RideStore!
    override func setUp() async throws {
        suite = "RidesDemoTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        vault = MemoryRideVault()
        api = StubRideAPI()
        store = RideStore(defaults: defaults, vault: vault, apiFactory: { [api = api!] _ in api })
        store.serverAddress = "https://demo.example.com"
    }
    override func tearDown() async throws { defaults.removePersistentDomain(forName: suite) }
    #if os(iOS)
    func testSimulatorKeychainCanSaveRestoreUpdateAndClearSession() async throws {
        let secureVault = KeychainRideSessionVault(account: "test-\(UUID().uuidString)")
        defer { secureVault.clear() }
        let session = try await api.create(name: "Keychain fixture")
        let stored = StoredRideSession(session, baseURL: api.baseURL)
        try secureVault.save(stored)
        XCTAssertEqual(secureVault.load()?.participantId, stored.participantId)
        XCTAssertEqual(secureVault.load()?.token, stored.token)
        try secureVault.save(stored)
        XCTAssertEqual(secureVault.load()?.roomCode, stored.roomCode)
        secureVault.clear()
        XCTAssertNil(secureVault.load())
    }
    #endif
    func testConnectPersistsSessionInTheVaultNotUserDefaults() async {
        await store.connect(createNew: true)
        XCTAssertTrue(store.connected)
        XCTAssertNotNil(vault.value)
        XCTAssertNil(defaults.object(forKey: "token"))
        XCTAssertEqual(store.state?.revision, 1)
        let restored = RideStore(defaults: defaults, vault: vault, apiFactory: { [api = api!] _ in api })
        XCTAssertEqual(restored.credentials?.participantId, "rider-fixture")
    }
    func testDriverJoinsAndAvailabilityUsesItsParticipantID() async {
        store.chooseRole(.driver)
        store.roomInput = "DEMOABCD"
        await store.connect(createNew: false)
        XCTAssertEqual(store.role, .driver)
        XCTAssertFalse(store.isDriverOnline)
        await store.setOnline(true)
        XCTAssertTrue(store.isDriverOnline)
        await store.setOnline(false)
        XCTAssertFalse(store.isDriverOnline)
    }
    func testOlderPollCannotOverwriteNewerState() async {
        await store.connect(createNew: true)
        api.current = RideRoomState(roomCode: "DEMOABCD", revision: 9, driverOnline: true, onlineDriverIds: ["other"], trips: [])
        await store.sync()
        api.current = RideRoomState(roomCode: "DEMOABCD", revision: 2, driverOnline: false, onlineDriverIds: [], trips: [])
        await store.sync()
        XCTAssertEqual(store.state?.revision, 9)
    }
    func testExpiredTokenClearsSecureSession() async {
        await store.connect(createNew: true)
        api.failure = RideAPIError(status: 401, message: "Expired")
        await store.sync()
        XCTAssertFalse(store.connected)
        XCTAssertNil(vault.value)
        XCTAssertTrue(store.showConnection)
    }
    func testNetworkFailureKeepsLastSyncedStateAndSession() async {
        await store.connect(createNew: true)
        api.failure = URLError(.notConnectedToInternet)
        await store.sync()
        XCTAssertTrue(store.connected)
        XCTAssertEqual(store.state?.revision, 1)
        XCTAssertTrue(store.errorMessage?.hasPrefix("Connection lost.") == true)
    }
    func testSavedPlacesAndDefaultPaymentPersist() {
        store.savePlace(RideCatalog.places[4])
        store.savePlace(RideCatalog.places[4])
        store.defaultPayment = .cash
        let restored = RideStore(defaults: defaults, vault: vault)
        XCTAssertEqual(restored.savedPlaces.filter { $0.id == "coffee" }.count, 1)
        XCTAssertEqual(restored.defaultPayment, .cash)
        restored.beginBooking()
        XCTAssertEqual(restored.draft.payment, .cash)
    }
}
