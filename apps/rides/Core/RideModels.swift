import Foundation

enum DemoRole: String, Codable, CaseIterable, Identifiable {
    case rider, driver
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var defaultName: String { self == .rider ? "Alex Morgan" : "Jordan Lee" }
}

struct DemoPlace: Codable, Equatable, Identifiable, Hashable {
    let id: String
    var name: String
    var address: String
    let latitude: Double
    let longitude: Double
}

enum RideService: String, Codable, CaseIterable, Identifiable {
    case uberX, comfort, uberXL, green, black, pet
    var id: String { rawValue }
    var title: String {
        switch self {
        case .uberX: return "UberX"
        case .comfort: return "Comfort"
        case .uberXL: return "UberXL"
        case .green: return "Green"
        case .black: return "Black"
        case .pet: return "Uber Pet"
        }
    }
    var detail: String {
        switch self {
        case .uberX: return "Affordable, everyday rides"
        case .comfort: return "Newer cars with extra legroom"
        case .uberXL: return "Affordable rides for up to 6"
        case .green: return "A more sustainable ride"
        case .black: return "Premium rides in luxury cars"
        case .pet: return "A ride for you and your pet"
        }
    }
    var seats: Int { self == .uberXL ? 6 : 4 }
    var fareCents: Int {
        switch self {
        case .uberX: return 1840
        case .comfort: return 2490
        case .uberXL: return 2990
        case .green: return 1940
        case .black: return 3890
        case .pet: return 2140
        }
    }
    var icon: String { self == .uberXL ? "suv.side.fill" : "car.side.fill" }
}

enum DemoPayment: String, Codable, CaseIterable, Identifiable {
    case visa = "Demo Visa •••• 4242"
    case cash = "Demo Cash"
    case wallet = "Demo Wallet"
    var id: String { rawValue }
    var icon: String { self == .visa ? "creditcard.fill" : self == .cash ? "banknote.fill" : "wallet.pass.fill" }
}

enum TripStatus: String, Codable {
    case requested, accepted, arriving, inProgress = "in_progress", completed, cancelled
    var isActive: Bool { self != .completed && self != .cancelled }
    var canCancel: Bool { self == .requested || self == .accepted || self == .arriving }
    var title: String {
        switch self {
        case .requested: return "Finding your ride"
        case .accepted: return "Your driver is on the way"
        case .arriving: return "Your driver has arrived"
        case .inProgress: return "You're on your way"
        case .completed: return "Thanks for riding, Alex"
        case .cancelled: return "Your ride was cancelled"
        }
    }
}

struct DemoDriver: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let vehicle: String
    let plate: String
    let rating: Double
}

struct RideMessage: Codable, Equatable, Identifiable {
    let id: String
    let senderId: String
    let senderName: String
    let text: String
    let createdAt: String
}

struct DemoTrip: Codable, Equatable, Identifiable {
    let id: String
    let riderId: String
    let riderName: String
    let pickup: DemoPlace
    let destination: DemoPlace
    let stops: [DemoPlace]
    let service: String
    let paymentMethod: String
    let scheduledAt: String?
    let note: String
    let status: TripStatus
    let driver: DemoDriver?
    let fareCents: Int
    let createdAt: String
    let updatedAt: String
    let cancellationReason: String?
    let rating: Int?
    let tipCents: Int
    let messages: [RideMessage]

    var serviceTitle: String { RideService(rawValue: service)?.title ?? service }
    var shortID: String { String(id.prefix(8)).uppercased() }
    var totalCents: Int { fareCents + tipCents }
    var canMessage: Bool { driver != nil && status.isActive }
}

struct RideRoomState: Codable, Equatable {
    let roomCode: String
    let revision: Int
    let driverOnline: Bool
    let onlineDriverIds: [String]
    let trips: [DemoTrip]
    var activeTrip: DemoTrip? { trips.first { $0.status.isActive } }
}

struct RideSession: Codable, Equatable {
    let roomCode: String
    let participantId: String
    let token: String
    let role: DemoRole
    let name: String
    let state: RideRoomState
}

struct StoredRideSession: Codable {
    let baseURL: URL
    let roomCode: String
    let participantId: String
    let token: String
    let role: DemoRole
    let name: String

    init(_ session: RideSession, baseURL: URL) {
        self.baseURL = baseURL
        roomCode = session.roomCode
        participantId = session.participantId
        token = session.token
        role = session.role
        name = session.name
    }
}

struct BookingDraft: Equatable {
    var requestId = UUID().uuidString
    var pickup = RideCatalog.places[0]
    var destination: DemoPlace?
    var stops: [DemoPlace] = []
    var service: RideService = .uberX
    var payment: DemoPayment = .visa
    var scheduledAt: Date?
    var note = ""
    var fareCents: Int { service.fareCents + stops.count * 300 }
    var routeIsValid: Bool { destination != nil && destination?.id != pickup.id && !stops.contains(pickup) && !stops.contains(where: { $0.id == destination?.id }) && Set(stops.map(\.id)).count == stops.count }
    func validationError(now: Date = Date()) -> String? {
        guard routeIsValid else { return "Choose different pickup, stop, and destination locations." }
        guard stops.count <= 2 else { return "Add at most two stops." }
        guard note.count <= 300 else { return "Keep your pickup note under 300 characters." }
        if let scheduledAt, scheduledAt <= now || scheduledAt > now.addingTimeInterval(30 * 86400) {
            return "Reserve between now and 30 days from now."
        }
        return nil
    }
}

struct TripRequest: Codable {
    let requestId: String
    let pickup: DemoPlace
    let destination: DemoPlace
    let stops: [DemoPlace]
    let service: String
    let paymentMethod: String
    let scheduledAt: String?
    let note: String

    init(draft: BookingDraft) throws {
        if let error = draft.validationError() { throw RideAPIError(status: 0, message: error) }
        guard let destination = draft.destination else { throw RideAPIError(status: 0, message: "Choose a destination.") }
        requestId = draft.requestId
        pickup = draft.pickup
        self.destination = destination
        stops = draft.stops
        service = draft.service.rawValue
        paymentMethod = draft.payment.rawValue
        scheduledAt = draft.scheduledAt.map { ISO8601DateFormatter().string(from: $0) }
        note = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct RideAction: Codable {
    var action: String
    var reason: String?
    var rating: Int?
    var tipCents: Int?
    var text: String?
}

enum RideCatalog {
    static let places: [DemoPlace] = [
        .init(id: "brazos", name: "701 Brazos Street", address: "Downtown Austin, TX", latitude: 30.2682, longitude: -97.7405),
        .init(id: "airport", name: "Austin–Bergstrom International Airport", address: "3600 Presidential Blvd, Austin, TX", latitude: 30.1975, longitude: -97.6664),
        .init(id: "home", name: "Home", address: "1313 East 6th Street, Austin, TX", latitude: 30.2635, longitude: -97.7290),
        .init(id: "work", name: "Work", address: "600 Congress Avenue, Austin, TX", latitude: 30.2682, longitude: -97.7429),
        .init(id: "coffee", name: "Jo's Coffee", address: "1300 South Congress Avenue, Austin, TX", latitude: 30.2503, longitude: -97.7493),
        .init(id: "park", name: "Zilker Metropolitan Park", address: "2207 Lou Neff Road, Austin, TX", latitude: 30.2670, longitude: -97.7729),
        .init(id: "hotel", name: "The LINE Austin", address: "111 East Cesar Chavez Street, Austin, TX", latitude: 30.2628, longitude: -97.7438),
        .init(id: "museum", name: "Blanton Museum of Art", address: "200 East Martin Luther King Jr Blvd, Austin, TX", latitude: 30.2810, longitude: -97.7377)
    ]
    static func search(_ query: String, saved: [DemoPlace] = []) -> [DemoPlace] {
        let places = saved + self.places.filter { place in !saved.contains { $0.id == place.id } }
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? places : places.filter { "\($0.name) \($0.address)".localizedCaseInsensitiveContains(text) }
    }
    static func money(_ cents: Int) -> String { (Double(cents) / 100).formatted(.currency(code: "USD")) }
    static func date(_ value: String) -> String {
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = parser.date(from: value) ?? ISO8601DateFormatter().date(from: value)
        return date?.formatted(date: .abbreviated, time: .shortened) ?? value
    }
}
