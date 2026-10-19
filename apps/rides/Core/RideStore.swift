import Combine
import Foundation
import Security

protocol RideSessionVault {
    func load() -> StoredRideSession?
    func save(_ session: StoredRideSession) throws
    func clear()
}

struct KeychainRideSessionVault: RideSessionVault {
    var account = "active-demo"
    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "com.revyl.ridesdemo.session", kSecAttrAccount as String: account]
    }
    func load() -> StoredRideSession? {
        var query = self.query
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var value: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &value) == errSecSuccess, let data = value as? Data else { return nil }
        return try? JSONDecoder().decode(StoredRideSession.self, from: data)
    }
    func save(_ session: StoredRideSession) throws {
        let data = try JSONEncoder().encode(session)
        let attributes: [String: Any] = [kSecValueData as String: data, kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecSuccess { return }
        guard status == errSecItemNotFound else { throw RideAPIError(status: 0, message: "Couldn't securely save the demo session (Keychain \(status)).") }
        var item = query
        attributes.forEach { item[$0.key] = $0.value }
        let added = SecItemAdd(item as CFDictionary, nil)
        guard added == errSecSuccess else { throw RideAPIError(status: 0, message: "Couldn't securely save the demo session (Keychain \(added)).") }
    }
    func clear() { SecItemDelete(query as CFDictionary) }
}

@MainActor
final class RideStore: ObservableObject {
    @Published private(set) var credentials: StoredRideSession?
    @Published private(set) var state: RideRoomState?
    @Published private(set) var lastSync: Date?
    @Published private(set) var busy = false
    @Published var errorMessage: String?
    @Published var notice: String?
    @Published var serverAddress: String
    @Published var roomInput = ""
    @Published var role: DemoRole
    @Published var displayName: String
    @Published var tab = 0
    @Published var draft = BookingDraft()
    @Published var showBooking = false
    @Published var showConnection = false
    @Published var focusedTripID: String?
    @Published var revylStatus: String?
    @Published var savedPlaces: [DemoPlace] {
        didSet { defaults.set(try? JSONEncoder().encode(savedPlaces), forKey: "savedPlaces") }
    }
    @Published var rideReminders: Bool {
        didSet { defaults.set(rideReminders, forKey: "rideReminders") }
    }
    @Published var defaultPayment: DemoPayment {
        didSet { defaults.set(defaultPayment.rawValue, forKey: "defaultPayment") }
    }
    private let defaults: UserDefaults
    private let vault: any RideSessionVault
    private let apiFactory: (URL) -> any RideAPI
    private var api: (any RideAPI)?

    init(defaults: UserDefaults = .standard, vault: any RideSessionVault = KeychainRideSessionVault(), apiFactory: @escaping (URL) -> any RideAPI = { RideAPIClient(baseURL: $0) }) {
        self.defaults = defaults
        self.vault = vault
        self.apiFactory = apiFactory
        let restored = vault.load()
        credentials = restored
        role = restored?.role ?? .rider
        displayName = restored?.name ?? DemoRole.rider.defaultName
        serverAddress = restored?.baseURL.absoluteString ?? RevylRideSignIn.launchValue("RIDE_DEMO_BASE_URL") ?? defaults.string(forKey: "serverAddress") ?? ""
        savedPlaces = defaults.data(forKey: "savedPlaces").flatMap { try? JSONDecoder().decode([DemoPlace].self, from: $0) } ?? [RideCatalog.places[2], RideCatalog.places[3]]
        rideReminders = defaults.object(forKey: "rideReminders") as? Bool ?? true
        defaultPayment = defaults.string(forKey: "defaultPayment").flatMap(DemoPayment.init(rawValue:)) ?? .visa
        if let restored { api = apiFactory(restored.baseURL) }
    }

    var connected: Bool { credentials != nil }
    var isDriverOnline: Bool { state?.onlineDriverIds.contains(credentials?.participantId ?? "") == true }
    var activeTrip: DemoTrip? { state?.activeTrip }
    var focusedTrip: DemoTrip? { state?.trips.first { $0.id == focusedTripID } }
    var myDriverTrip: DemoTrip? { activeTrip.flatMap { $0.driver?.id == credentials?.participantId ? $0 : nil } }
    var pastTrips: [DemoTrip] { (state?.trips ?? []).filter { !$0.status.isActive } }
    var earningsCents: Int {
        (state?.trips ?? []).filter { $0.status == .completed && $0.driver?.id == credentials?.participantId }.reduce(0) { $0 + $1.totalCents }
    }
    var syncIsFresh: Bool { lastSync.map { Date().timeIntervalSince($0) < 5 } ?? false }

    func chooseRole(_ value: DemoRole) {
        guard !connected else { return }
        role = value
        displayName = value.defaultName
    }

    func connect(createNew: Bool) async {
        guard !busy, !connected else { return }
        busy = true
        defer { busy = false }
        do {
            let url = try RideAPIClient.validatedURL(serverAddress)
            let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, name.count <= 60 else { throw RideAPIError(status: 0, message: "Enter a demo name of up to 60 characters.") }
            guard !createNew || role == .rider else { throw RideAPIError(status: 0, message: "Create the room on the rider phone first.") }
            let code = roomInput.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            guard createNew || (!code.isEmpty && code.count <= 32 && code.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) })) else { throw RideAPIError(status: 0, message: "Enter the invitation code from the rider phone.") }
            let client = apiFactory(url)
            let session: RideSession
            if createNew { session = try await client.create(name: name) }
            else { session = try await client.join(code: code, role: role, name: name) }
            let stored = StoredRideSession(session, baseURL: url)
            try vault.save(stored)
            api = client
            credentials = stored
            displayName = session.name
            role = session.role
            defaults.set(url.absoluteString, forKey: "serverAddress")
            apply(session.state, for: stored)
            errorMessage = nil
            notice = "Connected as \(role.title.lowercased())."
        } catch { errorMessage = error.localizedDescription }
    }

    func disconnect() {
        guard activeTrip == nil else { errorMessage = "Finish or cancel the active ride before leaving this demo."; return }
        credentials = nil
        api = nil
        state = nil
        lastSync = nil
        focusedTripID = nil
        roomInput = ""
        vault.clear()
    }

    func runPolling() async {
        while !Task.isCancelled {
            if connected { await sync() }
            do { try await Task.sleep(for: .seconds(1)) } catch { return }
        }
    }

    func sync() async {
        guard let credentials, let api else { return }
        do {
            let state = try await api.state(token: credentials.token)
            guard !Task.isCancelled else { return }
            apply(state, for: credentials)
        } catch {
            guard !Task.isCancelled, self.credentials?.token == credentials.token else { return }
            if let error = error as? RideAPIError, [401, 404].contains(error.status) {
                self.credentials = nil
                self.api = nil
                state = nil
                lastSync = nil
                vault.clear()
                showConnection = true
                errorMessage = "This demo session has expired. Create or join a room again."
            } else {
                errorMessage = "Connection lost. Check the demo server and tap Retry."
            }
        }
    }

    private func apply(_ incoming: RideRoomState, for credentials: StoredRideSession) {
        guard self.credentials?.token == credentials.token, incoming.roomCode == credentials.roomCode else { return }
        guard state == nil || incoming.revision >= state!.revision else { return }
        state = incoming
        lastSync = Date()
        if errorMessage?.hasPrefix("Connection lost.") == true { errorMessage = nil }
    }

    private func perform(_ action: (any RideAPI, StoredRideSession) async throws -> RideRoomState) async -> Bool {
        guard !busy else { return false }
        guard let api, let credentials else { showConnection = true; return false }
        busy = true
        defer { busy = false }
        do {
            let result = try await action(api, credentials)
            apply(result, for: credentials)
            errorMessage = nil
            return true
        } catch {
            if (error as? RideAPIError)?.status == 409 { await sync() }
            errorMessage = error.localizedDescription
            return false
        }
    }

    func setOnline(_ online: Bool) async {
        _ = await perform { api, session in try await api.availability(token: session.token, online: online) }
    }
    func book() async {
        do {
            let request = try TripRequest(draft: draft)
            if await perform({ api, session in try await api.book(token: session.token, request: request) }) {
                focusedTripID = activeTrip?.id
                showBooking = false
                tab = 0
                draft = BookingDraft()
            }
        } catch { errorMessage = error.localizedDescription }
    }
    @discardableResult
    func act(_ trip: DemoTrip, _ action: RideAction) async -> Bool {
        await perform { api, session in try await api.act(token: session.token, tripID: trip.id, action: action) }
    }
    func savePlace(_ place: DemoPlace) {
        if !savedPlaces.contains(where: { $0.id == place.id }) { savedPlaces.append(place) }
    }
    func beginBooking(destination: DemoPlace? = nil, reserve: Bool = false) {
        if activeTrip != nil { tab = 0; return }
        draft = BookingDraft()
        draft.payment = defaultPayment
        draft.destination = destination
        if reserve { draft.scheduledAt = Date().addingTimeInterval(3600) }
        showBooking = true
    }
    func handle(_ url: URL, environment: [String: String] = ProcessInfo.processInfo.environment, arguments: [String] = ProcessInfo.processInfo.arguments) async {
        #if DEBUG
        switch RevylRideSignIn.validate(url, environment: environment, arguments: arguments, isTestBuild: true) {
        case .ignored: return
        case .rejected(let reason): revylStatus = "Revyl sign-in rejected: \(reason)"
        case .accepted(let role, let tab):
            guard credentials == nil || credentials?.role == role else { revylStatus = "Revyl sign-in rejected: Leave the current demo before switching roles"; return }
            chooseRole(role)
            self.tab = tab
            revylStatus = "Revyl sign-in accepted · \(role.title)"
            if let value = RevylRideSignIn.launchValue("RIDE_DEMO_BASE_URL", environment: environment, arguments: arguments) { serverAddress = value }
            if let code = RevylRideSignIn.launchValue("RIDE_DEMO_ROOM_CODE", environment: environment, arguments: arguments), !code.isEmpty {
                roomInput = code
                await connect(createNew: false)
            }
        }
        #endif
    }
}
