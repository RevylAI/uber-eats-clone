import Foundation
import XCTest
@testable import RidesDemo

final class RideAccountModelTests: XCTestCase {
    func testAccountTokensUseDispatchAndLegacyTokensKeepTheRoomModule() {
        XCTAssertEqual(ConvexRideAPIClient.module(for: AccountFixture.token), "dispatch")
        for token in ["legacy-fixture", "", "user", "User.fixture", "prefix.user.fixture"] {
            XCTAssertEqual(ConvexRideAPIClient.module(for: token), "rides", token)
        }
    }

    func testLegacySessionAndStoredSessionDecodeWithoutAccountOrExpiry() throws {
        let sessionData = Data("""
        {"roomCode":"LEGACY","participantId":"legacy-rider","token":"legacy-fixture","role":"rider","name":"Legacy fixture","state":{"roomCode":"LEGACY","revision":1,"driverOnline":false,"onlineDriverIds":[],"trips":[]}}
        """.utf8)
        let session = try JSONDecoder().decode(RideSession.self, from: sessionData)
        XCTAssertNil(session.account)
        XCTAssertNil(session.expiresAt)
        XCTAssertEqual(session.participantId, "legacy-rider")

        let storedData = Data("""
        {"baseURL":"https://fixture.convex.cloud","roomCode":"LEGACY","participantId":"legacy-rider","token":"legacy-fixture","role":"rider","name":"Legacy fixture"}
        """.utf8)
        let stored = try JSONDecoder().decode(StoredRideSession.self, from: storedData)
        XCTAssertNil(stored.account)
        XCTAssertNil(stored.expiresAt)
        XCTAssertEqual(stored.token, session.token)
    }

    func testAccountSessionAndSecureStoredSessionRoundTripTheirProfile() throws {
        for role in DemoRole.allCases {
            let session = AccountFixture.session(role: role)
            let decoded = try JSONDecoder().decode(RideSession.self, from: JSONEncoder().encode(session))
            XCTAssertEqual(decoded, session)

            let stored = StoredRideSession(session, baseURL: AccountFixture.baseURL)
            let restored = try JSONDecoder().decode(StoredRideSession.self, from: JSONEncoder().encode(stored))
            XCTAssertEqual(restored.baseURL, AccountFixture.baseURL)
            XCTAssertEqual(restored.roomCode, session.roomCode)
            XCTAssertEqual(restored.participantId, session.participantId)
            XCTAssertEqual(restored.token, session.token)
            XCTAssertEqual(restored.role, role)
            XCTAssertEqual(restored.name, session.name)
            XCTAssertEqual(restored.account, session.account)
            XCTAssertEqual(restored.expiresAt, session.expiresAt)
        }
    }
}

@MainActor
final class RideAccountStoreTests: XCTestCase {
    private var suite: String!
    private var defaults: UserDefaults!
    private var vault: AccountTestVault!
    private var api: AccountTestAPI!
    private var store: RideStore!

    override func setUp() async throws {
        suite = "RideAccountTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        vault = AccountTestVault()
        api = AccountTestAPI()
        store = RideStore(defaults: defaults, vault: vault, apiFactory: { [api = api!] _ in api })
        store.serverAddress = AccountFixture.baseURL.absoluteString
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suite)
    }

    func testSignUpPersistsOnlyTheAccountSessionInTheSecureVault() async throws {
        let registration = AccountFixture.registration(role: .driver)
        api.session = AccountFixture.session(role: .driver)
        api.current = api.session.state
        store.showSignIn = true

        let succeeded = await store.signIn(email: "ignored@example.invalid", password: "unused-fixture", registration: registration)

        XCTAssertTrue(succeeded)
        XCTAssertEqual(api.registrations.count, 1)
        XCTAssertEqual(api.registrations.first?.name, registration.name)
        XCTAssertEqual(api.registrations.first?.email, registration.email)
        XCTAssertEqual(api.registrations.first?.password, registration.password)
        XCTAssertEqual(api.registrations.first?.role, .driver)
        XCTAssertEqual(api.registrations.first?.vehicle, registration.vehicle)
        XCTAssertEqual(api.registrations.first?.plate, registration.plate)
        XCTAssertEqual(api.signInCount, 0)
        XCTAssertEqual(store.account, api.session.account)
        XCTAssertEqual(store.role, .driver)
        XCTAssertFalse(store.showSignIn)
        XCTAssertFalse(store.busy)
        try assertSecurePersistence(password: registration.password)
        assertNoRoomCalls()
    }

    func testSignInUsesDatabaseProfileRatherThanTheLocallySelectedRole() async throws {
        store.chooseRole(.driver)
        let succeeded = await store.signIn(email: AccountFixture.email, password: AccountFixture.password)

        XCTAssertTrue(succeeded)
        XCTAssertEqual(api.signInCount, 1)
        XCTAssertEqual(api.signedInEmail, AccountFixture.email)
        XCTAssertEqual(api.signedInPassword, AccountFixture.password)
        XCTAssertTrue(api.registrations.isEmpty)
        XCTAssertEqual(store.role, .rider)
        XCTAssertEqual(store.displayName, api.session.account?.name)
        XCTAssertEqual(store.account, api.session.account)
        try assertSecurePersistence(password: AccountFixture.password)
        assertNoRoomCalls()
    }

    func testFailedCredentialsNeverInstallOrPersistASession() async {
        api.authenticationFailure = RideAPIError(status: 401, message: "Invalid email or password")

        let succeeded = await store.signIn(email: AccountFixture.email, password: "incorrect-fixture")

        XCTAssertFalse(succeeded)
        assertSignedOut()
        XCTAssertEqual(vault.saveCount, 0)
        XCTAssertTrue(api.revokedTokens.isEmpty)
        XCTAssertNotNil(store.errorMessage)
        XCTAssertFalse(store.busy)
        XCTAssertTrue((defaults.persistentDomain(forName: suite) ?? [:]).isEmpty)
        assertNoRoomCalls()
    }

    func testInvalidAccountIdentityRoleNameTokenAndExpiryAreRejectedAndRevoked() async {
        var missingAccount = AccountFixture.session()
        missingAccount.account = nil
        var missingExpiry = AccountFixture.session()
        missingExpiry.expiresAt = nil
        let invalidSessions: [(String, RideSession)] = [
            ("missing account", missingAccount),
            ("participant identity", AccountFixture.session(participantID: "other-user")),
            ("session identity", AccountFixture.session(roomCode: "other-user")),
            ("state identity", AccountFixture.session(stateRoomCode: "other-user")),
            ("role", AccountFixture.session(sessionRole: .driver)),
            ("name", AccountFixture.session(sessionName: "Different fixture")),
            ("legacy token", AccountFixture.session(token: "legacy-fixture")),
            ("short account token", AccountFixture.session(token: "user.short")),
            ("missing expiry", missingExpiry),
            ("expired", AccountFixture.session(expiresAt: 1)),
            ("nonfinite expiry", AccountFixture.session(expiresAt: .infinity)),
            ("invalid expiry", AccountFixture.session(expiresAt: .nan))
        ]

        for (label, session) in invalidSessions {
            api.session = session
            let previousRevocations = api.revokedTokens.count
            let succeeded = await store.signIn(email: AccountFixture.email, password: AccountFixture.password)

            XCTAssertFalse(succeeded, label)
            assertSignedOut()
            XCTAssertEqual(vault.saveCount, 0, label)
            XCTAssertEqual(api.revokedTokens.count, previousRevocations + 1, label)
            XCTAssertEqual(api.revokedTokens.last, session.token, label)
            XCTAssertNotNil(store.errorMessage, label)
        }
        assertNoRoomCalls()
    }

    func testSignUpCannotInstallAnAccountWithADifferentDatabaseRole() async {
        let succeeded = await store.signIn(email: AccountFixture.email, password: AccountFixture.password, registration: AccountFixture.registration(role: .driver))

        XCTAssertFalse(succeeded)
        assertSignedOut()
        XCTAssertEqual(api.revokedTokens, [api.session.token])
        XCTAssertEqual(vault.saveCount, 0)
    }

    func testSecureStorageFailureRevokesTheNewSessionWithoutConnecting() async {
        vault.failure = RideAPIError(status: 0, message: "Synthetic vault failure")

        let succeeded = await store.signIn(email: AccountFixture.email, password: AccountFixture.password)

        XCTAssertFalse(succeeded)
        assertSignedOut()
        XCTAssertEqual(api.revokedTokens, [api.session.token])
        XCTAssertEqual(vault.saveCount, 1)
    }

    func testCancelledSignUpRevokesALateSessionWithoutPersistingIt() async {
        let started = expectation(description: "Sign-up request suspended")
        api.suspendSignUp = true
        api.onSignUpSuspended = { started.fulfill() }
        let task = Task { await store.signIn(email: AccountFixture.email, password: AccountFixture.password, registration: AccountFixture.registration()) }
        await fulfillment(of: [started], timeout: 2)

        task.cancel()
        api.signUpContinuation?.resume(returning: api.session)
        api.signUpContinuation = nil
        let succeeded = await task.value

        XCTAssertFalse(succeeded)
        assertSignedOut()
        XCTAssertEqual(vault.saveCount, 0)
        XCTAssertEqual(api.revokedTokens, [api.session.token])
        XCTAssertFalse(store.busy)
        XCTAssertNil(store.errorMessage)
    }

    func testAccountRestoresTheSecureProfileAndFindsItsActiveTripOnSync() async throws {
        let trip = AccountFixture.trip(status: .accepted)
        let session = AccountFixture.session(trips: [trip])
        try vault.save(StoredRideSession(session, baseURL: api.baseURL))
        api.current = session.state

        let restored = RideStore(defaults: defaults, vault: vault, apiFactory: { [api = api!] _ in api })

        XCTAssertTrue(restored.connected)
        XCTAssertEqual(restored.account, session.account)
        XCTAssertEqual(restored.role, session.role)
        XCTAssertEqual(restored.displayName, session.name)
        XCTAssertEqual(restored.serverAddress, api.baseURL.absoluteString)
        await restored.sync()
        XCTAssertEqual(restored.activeTrip, trip)
        XCTAssertEqual(restored.focusedTripID, trip.id)
        XCTAssertEqual(restored.state, session.state)
        XCTAssertEqual(api.stateTokens, [session.token])
        XCTAssertEqual(api.signInCount, 0)
        XCTAssertTrue(api.resumeTokens.isEmpty)
        assertNoRoomCalls()
    }

    func testAccountOnlyStartupDiscardsLegacyRoomsAndCustomServerDefaults() throws {
        let oldState = RideRoomState(roomCode: "LEGACY", revision: 1, driverOnline: false, onlineDriverIds: [], trips: [])
        let oldSession = RideSession(roomCode: "LEGACY", participantId: "legacy-rider", token: "legacy-fixture", role: .rider, name: "Legacy fixture", state: oldState)
        try vault.save(StoredRideSession(oldSession, baseURL: URL(string: "https://old-service.example.invalid")!))
        defaults.set("https://old-service.example.invalid", forKey: "serverAddress")

        let upgraded = RideStore(defaults: defaults, vault: vault, accountOnly: true)

        XCTAssertFalse(upgraded.connected)
        XCTAssertNil(upgraded.account)
        XCTAssertNil(vault.value)
        XCTAssertEqual(upgraded.serverAddress, RideBackend.defaultAddress)
    }

    func testSignOutRevokesTheSessionAndClearsAccountAndTripState() async {
        let succeeded = await store.signIn(email: AccountFixture.email, password: AccountFixture.password)
        XCTAssertTrue(succeeded)
        store.roomInput = "STALE"
        store.focusedTripID = "stale-trip"
        store.draft.destination = RideCatalog.places[1]
        store.draft.note = "Synthetic draft"
        store.showBooking = true
        store.notice = "Synthetic notice"
        store.revylStatus = "Synthetic status"
        store.tab = 3

        await store.signOut()

        assertSignedOut()
        XCTAssertEqual(api.stateTokens, [api.session.token])
        XCTAssertEqual(api.revokedTokens, [api.session.token])
        XCTAssertEqual(vault.clearCount, 1)
        XCTAssertNil(store.lastSync)
        XCTAssertFalse(store.syncConnected)
        XCTAssertNil(store.focusedTripID)
        XCTAssertEqual(store.roomInput, "")
        XCTAssertNil(store.draft.destination)
        XCTAssertEqual(store.draft.note, "")
        XCTAssertFalse(store.showBooking)
        XCTAssertNil(store.notice)
        XCTAssertNil(store.revylStatus)
        XCTAssertTrue(store.showSignIn)
        XCTAssertNil(store.errorMessage)
        XCTAssertFalse(store.busy)
        XCTAssertEqual(store.tab, 0)
        XCTAssertEqual(store.role, .rider)
        XCTAssertEqual(store.displayName, "")
    }

    func testDriverSignOutClearsTheDatabaseProfileAndGoesOfflineBeforeRevocation() async {
        api.session = AccountFixture.session(role: .driver)
        api.current = api.session.state
        let succeeded = await store.signIn(email: AccountFixture.email, password: AccountFixture.password)
        XCTAssertTrue(succeeded)

        await store.signOut()

        assertSignedOut()
        XCTAssertEqual(api.events, ["state", "offline", "revoke"])
        XCTAssertEqual(api.availabilityTokens, [api.session.token])
        XCTAssertEqual(store.role, .rider)
        XCTAssertEqual(store.displayName, "")
    }

    func testRiderCannotSignOutOrDisconnectWhileOwningAnActiveTrip() async {
        let succeeded = await store.signIn(email: AccountFixture.email, password: AccountFixture.password)
        XCTAssertTrue(succeeded)
        api.current = AccountFixture.session(trips: [AccountFixture.trip(status: .inProgress)]).state

        await store.signOut()
        store.disconnect()

        XCTAssertTrue(store.connected)
        XCTAssertNotNil(store.ownedActiveTrip)
        XCTAssertNotNil(vault.value)
        XCTAssertTrue(api.revokedTokens.isEmpty)
        XCTAssertEqual(vault.clearCount, 0)
        XCTAssertNotNil(store.errorMessage)
        XCTAssertFalse(store.busy)
    }

    func testDriverCannotSignOutWhileAssignedAnActiveTrip() async {
        let driver = AccountFixture.driver()
        api.session = AccountFixture.session(role: .driver, trips: [AccountFixture.trip(id: "offer-fixture", status: .requested), AccountFixture.trip(status: .accepted, driver: driver)])
        api.current = api.session.state
        let succeeded = await store.signIn(email: AccountFixture.email, password: AccountFixture.password)
        XCTAssertTrue(succeeded)
        XCTAssertEqual(store.activeTrip?.id, "offer-fixture")
        XCTAssertEqual(store.myDriverTrip?.id, "account-trip-fixture")

        await store.signOut()

        XCTAssertTrue(store.connected)
        XCTAssertEqual(store.ownedActiveTrip?.driver?.id, driver.id)
        XCTAssertTrue(api.availabilityTokens.isEmpty)
        XCTAssertTrue(api.revokedTokens.isEmpty)
        XCTAssertNotNil(vault.value)
    }

    func testUnassignedDriverOfferDoesNotCountAsAnOwnedActiveTrip() async {
        api.session = AccountFixture.session(role: .driver, trips: [AccountFixture.trip(status: .requested)])
        api.current = api.session.state
        let succeeded = await store.signIn(email: AccountFixture.email, password: AccountFixture.password)
        XCTAssertTrue(succeeded)
        XCTAssertNotNil(store.activeTrip)
        XCTAssertNil(store.myDriverTrip)
        XCTAssertNil(store.ownedActiveTrip)

        await store.signOut()

        assertSignedOut()
        XCTAssertEqual(api.events, ["state", "offline", "revoke"])
    }

    func testTripAssignedToAnotherDriverDoesNotBlockSignOut() async {
        let other = DemoDriver(id: "other-driver", name: "Other fixture", vehicle: "Fixture car", plate: "TEST 002", rating: 4.9)
        api.session = AccountFixture.session(role: .driver, trips: [AccountFixture.trip(status: .accepted, driver: other)])
        api.current = api.session.state
        let succeeded = await store.signIn(email: AccountFixture.email, password: AccountFixture.password)
        XCTAssertTrue(succeeded)
        XCTAssertNil(store.ownedActiveTrip)

        await store.signOut()

        assertSignedOut()
        XCTAssertEqual(api.revokedTokens, [api.session.token])
    }

    func testRevokedSessionClearsSecureCredentialsEvenWithAnOwnedTrip() async {
        api.session = AccountFixture.session(trips: [AccountFixture.trip(status: .inProgress)])
        api.current = api.session.state
        let succeeded = await store.signIn(email: AccountFixture.email, password: AccountFixture.password)
        XCTAssertTrue(succeeded)
        store.draft.destination = RideCatalog.places[1]
        store.showBooking = true
        api.stateFailure = RideAPIError(status: 401, message: "Session revoked")

        await store.sync()

        assertSignedOut()
        XCTAssertNil(store.lastSync)
        XCTAssertNil(store.focusedTripID)
        XCTAssertNil(store.draft.destination)
        XCTAssertFalse(store.showBooking)
        XCTAssertFalse(store.syncConnected)
        XCTAssertEqual(store.role, .rider)
        XCTAssertEqual(store.displayName, "")
        XCTAssertTrue(store.showSignIn)
        XCTAssertTrue(store.errorMessage?.contains("expired") == true)
    }

    func testSignOutNetworkFailureKeepsTheSessionForRetry() async {
        let succeeded = await store.signIn(email: AccountFixture.email, password: AccountFixture.password)
        XCTAssertTrue(succeeded)
        api.signOutFailure = URLError(.notConnectedToInternet)

        await store.signOut()

        XCTAssertTrue(store.connected)
        XCTAssertNotNil(vault.value)
        XCTAssertNotNil(store.errorMessage)
        XCTAssertEqual(vault.clearCount, 0)
        XCTAssertFalse(store.busy)
    }

    func testSignOutConflictRefreshesANewlyAssignedTripAndKeepsTheSession() async {
        let succeeded = await store.signIn(email: AccountFixture.email, password: AccountFixture.password)
        XCTAssertTrue(succeeded)
        let trip = AccountFixture.trip(status: .accepted)
        api.stateResponses = [api.session.state, AccountFixture.session(trips: [trip]).state]
        api.signOutFailure = RideAPIError(status: 409, message: "Finish the active ride before signing out")

        await store.signOut()

        XCTAssertTrue(store.connected)
        XCTAssertEqual(store.ownedActiveTrip, trip)
        XCTAssertNotNil(vault.value)
        XCTAssertEqual(vault.clearCount, 0)
        XCTAssertEqual(api.stateTokens, [api.session.token, api.session.token])
        XCTAssertEqual(store.errorMessage, "Finish the active ride before signing out")
        XCTAssertFalse(store.busy)
    }

    #if DEBUG
    func testRevylGateResumesAnExistingAccountWithoutCreatingOrJoiningRooms() async {
        await store.handle(AccountFixture.link(), environment: AccountFixture.environment(), arguments: [])

        XCTAssertTrue(store.connected)
        XCTAssertEqual(store.account, api.session.account)
        XCTAssertEqual(store.tab, 2)
        XCTAssertEqual(api.resumeTokens, [AccountFixture.token])
        XCTAssertEqual(vault.value?.token, AccountFixture.token)
        XCTAssertTrue(store.revylStatus?.contains("accepted") == true)
        XCTAssertEqual(api.signInCount, 0)
        XCTAssertTrue(api.registrations.isEmpty)
        assertNoRoomCalls()
    }

    func testRevylGateCannotSpoofTheDatabaseAccountRole() async {
        await store.handle(AccountFixture.link(role: .driver), environment: AccountFixture.environment(), arguments: [])

        assertSignedOut()
        XCTAssertEqual(api.resumeTokens, [AccountFixture.token])
        XCTAssertEqual(vault.saveCount, 0)
        XCTAssertTrue(store.revylStatus?.contains("rejected") == true)
        assertNoRoomCalls()
    }

    func testRevylGateRequiresASeparateAccountSessionToken() async {
        for token in [nil, "legacy-fixture"] as [String?] {
            await store.handle(AccountFixture.link(), environment: AccountFixture.environment(accountToken: token), arguments: [])

            assertSignedOut()
            XCTAssertTrue(api.resumeTokens.isEmpty)
            XCTAssertEqual(vault.saveCount, 0)
            XCTAssertTrue(store.revylStatus?.contains("rejected") == true)
        }
        assertNoRoomCalls()
    }

    func testRevylGateRejectsAResumedSessionWithADifferentToken() async {
        api.session = AccountFixture.session(token: "user." + String(repeating: "b", count: 43))

        await store.handle(AccountFixture.link(), environment: AccountFixture.environment(), arguments: [])

        assertSignedOut()
        XCTAssertEqual(vault.saveCount, 0)
        XCTAssertTrue(store.revylStatus?.contains("rejected") == true)
        assertNoRoomCalls()
    }

    func testRevylGateDoesNotContactAccountsWhenTheGateIsDisabledOrWrong() async {
        var disabled = AccountFixture.environment()
        disabled["RIDES_AUTH_BYPASS_ENABLED"] = "false"
        await store.handle(AccountFixture.link(), environment: disabled, arguments: [])
        await store.handle(AccountFixture.link(gateToken: "wrong-fixture"), environment: AccountFixture.environment(), arguments: [])

        assertSignedOut()
        XCTAssertTrue(api.resumeTokens.isEmpty)
        XCTAssertEqual(vault.saveCount, 0)
        assertNoRoomCalls()
    }
    #else
    func testReleaseBuildIgnoresTheRevylAccountGate() async {
        await store.handle(AccountFixture.link(), environment: AccountFixture.environment(), arguments: [])

        assertSignedOut()
        XCTAssertTrue(api.resumeTokens.isEmpty)
        XCTAssertEqual(vault.saveCount, 0)
        XCTAssertNil(store.revylStatus)
        assertNoRoomCalls()
    }
    #endif

    private func assertSecurePersistence(password: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let stored = try XCTUnwrap(vault.value, file: file, line: line)
        XCTAssertEqual(vault.saveCount, 1, file: file, line: line)
        XCTAssertEqual(stored.account, api.session.account, file: file, line: line)
        XCTAssertEqual(stored.token, api.session.token, file: file, line: line)
        let encoded = try JSONEncoder().encode(stored)
        let fields = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any], file: file, line: line)
        XCTAssertEqual(Set(fields.keys), Set(["baseURL", "roomCode", "participantId", "token", "role", "name", "account", "expiresAt"]), file: file, line: line)
        let profile = try XCTUnwrap(fields["account"] as? [String: Any], file: file, line: line)
        XCTAssertNil(profile["password"], file: file, line: line)
        XCTAssertNil(profile["passwordHash"], file: file, line: line)
        XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains(password), file: file, line: line)
        XCTAssertTrue((defaults.persistentDomain(forName: suite) ?? [:]).isEmpty, file: file, line: line)
    }

    private func assertSignedOut(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(store.connected, file: file, line: line)
        XCTAssertNil(store.credentials, file: file, line: line)
        XCTAssertNil(store.account, file: file, line: line)
        XCTAssertNil(store.state, file: file, line: line)
        XCTAssertNil(vault.value, file: file, line: line)
    }

    private func assertNoRoomCalls(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(api.createCount, 0, file: file, line: line)
        XCTAssertEqual(api.joinCount, 0, file: file, line: line)
    }
}

private final class AccountTestVault: RideSessionVault {
    var value: StoredRideSession?
    var saveCount = 0
    var clearCount = 0
    var failure: Error?

    func load() -> StoredRideSession? { value }
    func save(_ session: StoredRideSession) throws {
        saveCount += 1
        if let failure { throw failure }
        value = session
    }
    func clear() {
        clearCount += 1
        value = nil
    }
}

private final class AccountTestAPI: RideAPI {
    let baseURL = AccountFixture.baseURL
    var session = AccountFixture.session()
    var current = AccountFixture.session().state
    var authenticationFailure: Error?
    var stateFailure: Error?
    var stateResponses: [RideRoomState] = []
    var signOutFailure: Error?
    var registrations: [RideRegistration] = []
    var signInCount = 0
    var signedInEmail: String?
    var signedInPassword: String?
    var resumeTokens: [String] = []
    var revokedTokens: [String] = []
    var stateTokens: [String] = []
    var availabilityTokens: [String] = []
    var events: [String] = []
    var createCount = 0
    var joinCount = 0
    var suspendSignUp = false
    var onSignUpSuspended: (() -> Void)?
    var signUpContinuation: CheckedContinuation<RideSession, Error>?

    func signUp(_ registration: RideRegistration) async throws -> RideSession {
        registrations.append(registration)
        if let authenticationFailure { throw authenticationFailure }
        if suspendSignUp {
            return try await withCheckedThrowingContinuation { continuation in
                signUpContinuation = continuation
                onSignUpSuspended?()
            }
        }
        return session
    }
    func signIn(email: String, password: String) async throws -> RideSession {
        signInCount += 1
        signedInEmail = email
        signedInPassword = password
        if let authenticationFailure { throw authenticationFailure }
        return session
    }
    func resume(token: String) async throws -> RideSession {
        resumeTokens.append(token)
        if let authenticationFailure { throw authenticationFailure }
        return session
    }
    func signOut(token: String) async throws {
        events.append("revoke")
        revokedTokens.append(token)
        if let signOutFailure { throw signOutFailure }
    }
    func create(name: String) async throws -> RideSession {
        createCount += 1
        throw RideAPIError(status: 400, message: "Account tests must not create rooms")
    }
    func join(code: String, role: DemoRole, name: String) async throws -> RideSession {
        joinCount += 1
        throw RideAPIError(status: 400, message: "Account tests must not join rooms")
    }
    func state(token: String) async throws -> RideRoomState {
        stateTokens.append(token)
        events.append("state")
        if let stateFailure { throw stateFailure }
        if !stateResponses.isEmpty { return stateResponses.removeFirst() }
        return current
    }
    func availability(token: String, online: Bool) async throws -> RideRoomState {
        availabilityTokens.append(token)
        events.append(online ? "online" : "offline")
        return current
    }
    func book(token: String, request: TripRequest) async throws -> RideRoomState { current }
    func act(token: String, tripID: String, action: RideAction) async throws -> RideRoomState { current }
}

private enum AccountFixture {
    static let baseURL = URL(string: "https://fixture.convex.cloud")!
    static let token = "user." + String(repeating: "a", count: 43)
    static let email = "account-fixture@example.invalid"
    static let password = "Synthetic-test-password-2026!"
    static let gateToken = String(repeating: "g", count: 40)

    static func account(role: DemoRole = .rider) -> RideAccount {
        RideAccount(id: role == .driver ? "account-driver" : "account-rider", name: role == .driver ? "Driver fixture" : "Rider fixture", email: email, role: role, vehicle: role == .driver ? "Fixture sedan" : nil, plate: role == .driver ? "TEST 001" : nil)
    }

    static func registration(role: DemoRole = .rider) -> RideRegistration {
        let profile = account(role: role)
        return RideRegistration(name: profile.name, email: profile.email, password: password, role: role, vehicle: profile.vehicle, plate: profile.plate)
    }

    static func session(role: DemoRole = .rider, trips: [DemoTrip] = [], participantID: String? = nil, roomCode: String? = nil, stateRoomCode: String? = nil, sessionRole: DemoRole? = nil, sessionName: String? = nil, token: String = AccountFixture.token, expiresAt: Double = Date().addingTimeInterval(3600).timeIntervalSince1970 * 1000) -> RideSession {
        let profile = account(role: role)
        let state = RideRoomState(roomCode: stateRoomCode ?? profile.id, revision: 1, driverOnline: role == .driver, onlineDriverIds: role == .driver ? [profile.id] : [], trips: trips)
        return RideSession(roomCode: roomCode ?? profile.id, participantId: participantID ?? profile.id, token: token, role: sessionRole ?? role, name: sessionName ?? profile.name, state: state, account: profile, expiresAt: expiresAt)
    }

    static func driver() -> DemoDriver {
        let profile = account(role: .driver)
        return DemoDriver(id: profile.id, name: profile.name, vehicle: profile.vehicle!, plate: profile.plate!, rating: 4.9)
    }

    static func trip(id: String = "account-trip-fixture", status: TripStatus, driver: DemoDriver? = nil) -> DemoTrip {
        let rider = account()
        return DemoTrip(id: id, riderId: rider.id, riderName: rider.name, pickup: RideCatalog.places[0], destination: RideCatalog.places[1], stops: [], service: "uberX", paymentMethod: "Demo Cash", scheduledAt: nil, note: "", status: status, driver: driver, fareCents: 1840, createdAt: "2026-10-19T12:00:00.000Z", updatedAt: "2026-10-19T12:00:00.000Z", cancellationReason: nil, rating: nil, tipCents: 0, messages: [])
    }

    static func link(role: DemoRole = .rider, gateToken: String = AccountFixture.gateToken) -> URL {
        URL(string: "ridesdemo://revyl-auth?token=\(gateToken)&role=\(role.rawValue)&redirect=/activity")!
    }

    static func environment(accountToken: String? = AccountFixture.token) -> [String: String] {
        var result = ["RIDES_AUTH_BYPASS_ENABLED": "true", "RIDES_AUTH_BYPASS_TOKEN": gateToken]
        if let accountToken { result["RIDES_ACCOUNT_SESSION"] = accountToken }
        return result
    }
}
