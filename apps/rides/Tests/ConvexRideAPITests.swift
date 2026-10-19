import Combine
import ConvexMobile
import XCTest
@testable import RidesDemo

final class ConvexRideAPITests: XCTestCase {
    func testSecureTokensAreFreshURLSafeAndNeverAdminCredentials() throws {
        let first = try ConvexRideAPIClient.freshToken()
        let second = try ConvexRideAPIClient.freshToken()
        XCTAssertTrue(first != second)
        XCTAssertTrue(first.count >= 43)
        XCTAssertTrue(first.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") })
    }

    func testConvexAndLegacyBackendsSelectTheirOwnTransport() throws {
        let convex = try RideAPIClient.validatedURL("https://fixture.convex.cloud")
        let legacy = try RideAPIClient.validatedURL("https://legacy.example.com")
        XCTAssertTrue(RideBackend.client(for: convex) is ConvexRideAPIClient)
        XCTAssertTrue(RideBackend.client(for: legacy) is RideAPIClient)
    }

    func testConvexArgumentsKeepNumbersAndDoNotSendClientFares() throws {
        var draft = BookingDraft()
        draft.destination = RideCatalog.places[1]
        let request = try TripRequest(draft: draft)
        let encoded = try XCTUnwrap(request.convexEncode().data(using: .utf8))
        let value = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(value["service"] as? String, "uberX")
        XCTAssertNil(value["fareCents"])
        let action = RideAction(action: "rate", rating: 5, tipCents: 300)
        let data = try XCTUnwrap(action.convexEncode().data(using: .utf8))
        let rating = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(rating["rating"] as? Int, 5)
        XCTAssertEqual(rating["tipCents"] as? Int, 300)
    }

    func testStructuredErrorsPreserveStatusWithoutExposingInternalErrors() {
        let expected = ClientError.ConvexError(data: "{\"status\":409,\"message\":\"Trip is no longer available\"}")
        XCTAssertEqual(ConvexRideAPIClient.apiError(expected), RideAPIError(status: 409, message: "Trip is no longer available"))
        let internalFailure = ClientError.ServerError(msg: "private fixture data")
        let safe = ConvexRideAPIClient.apiError(internalFailure)
        XCTAssertEqual(safe.status, 0)
        XCTAssertFalse(safe.message.contains("private fixture"))
    }
}

private final class StreamRideVault: RideSessionVault {
    var value: StoredRideSession?
    func load() -> StoredRideSession? { value }
    func save(_ session: StoredRideSession) throws { value = session }
    func clear() { value = nil }
}

private final class StreamRideAPI: RideAPI {
    let baseURL = URL(string: "https://fixture.convex.cloud")!
    var continuation: AsyncThrowingStream<RideSyncEvent, Error>.Continuation?
    var subscribed: (() -> Void)?
    var mutationFailure: RideAPIError?
    var current = RideRoomState(roomCode: "FIXTUREABCD", revision: 1, driverOnline: false, onlineDriverIds: [], trips: [])
    func create(name: String) async throws -> RideSession { RideSession(roomCode: current.roomCode, participantId: "rider-fixture", token: "session-fixture", role: .rider, name: name, state: current) }
    func join(code: String, role: DemoRole, name: String) async throws -> RideSession { try await create(name: name) }
    func state(token: String) async throws -> RideRoomState { current }
    func availability(token: String, online: Bool) async throws -> RideRoomState { current }
    func book(token: String, request: TripRequest) async throws -> RideRoomState {
        if let mutationFailure { throw mutationFailure }
        return current
    }
    func act(token: String, tripID: String, action: RideAction) async throws -> RideRoomState { current }
    func updates(token: String) -> AsyncThrowingStream<RideSyncEvent, Error> {
        AsyncThrowingStream { continuation in
            self.continuation = continuation
            subscribed?()
        }
    }
}

@MainActor
final class RideRealtimeTests: XCTestCase {
    func testRealtimeUpdatesApplyWithoutPollingAndCancellationKeepsSession() async throws {
        let suite = "RidesRealtime.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let api = StreamRideAPI()
        let vault = StreamRideVault()
        let store = RideStore(defaults: defaults, vault: vault, apiFactory: { _ in api })
        store.serverAddress = api.baseURL.absoluteString
        await store.connect(createNew: true)
        let subscribed = expectation(description: "Subscribed to room changes")
        api.subscribed = { subscribed.fulfill() }
        let task = Task { await store.runUpdates() }
        await fulfillment(of: [subscribed], timeout: 2)
        let updated = expectation(description: "Applied server-pushed revision")
        let observer = store.$state.compactMap { $0 }.filter { $0.revision == 2 }.first().sink { _ in updated.fulfill() }
        api.continuation?.yield(.connection(true))
        api.continuation?.yield(.state(RideRoomState(roomCode: api.current.roomCode, revision: 2, driverOnline: true, onlineDriverIds: ["driver-fixture"], trips: [])))
        await fulfillment(of: [updated], timeout: 2)
        XCTAssertTrue(store.state?.driverOnline == true)
        XCTAssertTrue(store.syncIsFresh)
        task.cancel()
        await task.value
        observer.cancel()
        XCTAssertTrue(store.connected)
        XCTAssertNotNil(vault.value)
        XCTAssertFalse(store.syncIsFresh)
    }

    func testCachedStateDoesNotMarkADisconnectedStreamLive() async throws {
        let suite = "RidesOffline.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let api = StreamRideAPI()
        let store = RideStore(defaults: defaults, vault: StreamRideVault(), apiFactory: { _ in api })
        store.serverAddress = api.baseURL.absoluteString
        await store.connect(createNew: true)
        let subscribed = expectation(description: "Subscribed")
        api.subscribed = { subscribed.fulfill() }
        let task = Task { await store.runUpdates() }
        await fulfillment(of: [subscribed], timeout: 2)
        let updated = expectation(description: "Applied cached state")
        let observer = store.$state.compactMap { $0 }.filter { $0.revision == 2 }.first().sink { _ in updated.fulfill() }
        api.continuation?.yield(.connection(false))
        api.continuation?.yield(.state(RideRoomState(roomCode: api.current.roomCode, revision: 2, driverOnline: true, onlineDriverIds: ["driver-fixture"], trips: [])))
        await fulfillment(of: [updated], timeout: 2)
        XCTAssertFalse(store.syncIsFresh)
        task.cancel()
        await task.value
        observer.cancel()
    }

    func testExpiredRealtimeCredentialClearsVaultAndRequestsReconnection() async throws {
        let suite = "RidesRealtime.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let api = StreamRideAPI()
        let vault = StreamRideVault()
        let store = RideStore(defaults: defaults, vault: vault, apiFactory: { _ in api })
        store.serverAddress = api.baseURL.absoluteString
        await store.connect(createNew: true)
        let subscribed = expectation(description: "Subscribed")
        api.subscribed = { subscribed.fulfill() }
        let task = Task { await store.runUpdates() }
        await fulfillment(of: [subscribed], timeout: 2)
        api.continuation?.finish(throwing: RideAPIError(status: 401, message: "Expired"))
        await task.value
        XCTAssertFalse(store.connected)
        XCTAssertNil(vault.value)
        XCTAssertTrue(store.showConnection)
    }

    func testRestoredActiveRideKeepsItsReceiptFocusedWhenDriverCompletes() async throws {
        let suite = "RidesReceipt.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let api = StreamRideAPI()
        let vault = StreamRideVault()
        try vault.save(StoredRideSession(try await api.create(name: "Fixture rider"), baseURL: api.baseURL))
        let store = RideStore(defaults: defaults, vault: vault, apiFactory: { _ in api })
        func trip(_ status: TripStatus) -> DemoTrip {
            DemoTrip(id: "trip-fixture", riderId: "rider-fixture", riderName: "Fixture rider", pickup: RideCatalog.places[0], destination: RideCatalog.places[1], stops: [], service: "uberX", paymentMethod: "Demo Cash", scheduledAt: nil, note: "", status: status, driver: nil, fareCents: 1840, createdAt: "2026-10-19T12:00:00.000Z", updatedAt: "2026-10-19T12:00:00.000Z", cancellationReason: nil, rating: nil, tipCents: 0, messages: [])
        }
        api.current = RideRoomState(roomCode: api.current.roomCode, revision: 2, driverOnline: true, onlineDriverIds: [], trips: [trip(.inProgress)])
        await store.sync()
        XCTAssertEqual(store.focusedTripID, "trip-fixture")
        api.current = RideRoomState(roomCode: api.current.roomCode, revision: 3, driverOnline: true, onlineDriverIds: [], trips: [trip(.completed)])
        await store.sync()
        XCTAssertNil(store.activeTrip)
        XCTAssertEqual(store.focusedTrip?.status, .completed)
    }

    func testExpiredMutationClearsTheSessionEvenWithoutAnExpiryOnlyQueryPush() async throws {
        let suite = "RidesExpiredMutation.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let api = StreamRideAPI()
        let vault = StreamRideVault()
        let store = RideStore(defaults: defaults, vault: vault, apiFactory: { _ in api })
        store.serverAddress = api.baseURL.absoluteString
        await store.connect(createNew: true)
        api.mutationFailure = RideAPIError(status: 401, message: "Invalid or expired bearer token")
        store.draft.destination = RideCatalog.places[1]
        await store.book()
        XCTAssertFalse(store.connected)
        XCTAssertNil(vault.value)
        XCTAssertTrue(store.showConnection)
        XCTAssertTrue(store.errorMessage?.contains("expired") == true)
    }
}
