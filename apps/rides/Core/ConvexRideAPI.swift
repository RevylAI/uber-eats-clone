import Combine
import ConvexMobile
import Foundation
import Security

extension TripRequest: ConvexEncodable {}
extension RideAction: ConvexEncodable {}

final class ConvexRideAPIClient: RideAPI {
    let baseURL: URL
    private let client: ConvexClient
    private let connectionState = CurrentValueSubject<Bool, Never>(false)
    private var socketObservation: AnyCancellable?

    init(baseURL: URL) {
        self.baseURL = baseURL
        client = ConvexClient(deploymentUrl: baseURL.absoluteString)
        socketObservation = client.watchWebSocketState().sink { [connectionState] in connectionState.send($0 == .connected) }
    }

    static func freshToken() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw RideAPIError(status: 0, message: "Couldn't create a secure session. Try again.")
        }
        return Data(bytes).base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }

    static func module(for token: String) -> String { token.hasPrefix("user.") ? "dispatch" : "rides" }

    func signUp(_ registration: RideRegistration) async throws -> RideSession {
        do {
            return try await client.action("accounts:signUp", with: ["name": registration.name, "email": registration.email, "password": registration.password, "role": registration.role.rawValue, "vehicle": registration.vehicle, "plate": registration.plate])
        } catch { throw Self.apiError(error) }
    }

    func signIn(email: String, password: String) async throws -> RideSession {
        do { return try await client.action("accounts:signIn", with: ["email": email, "password": password]) }
        catch { throw Self.apiError(error) }
    }

    func resume(token: String) async throws -> RideSession {
        do {
            for try await session in client.subscribe(to: "accounts:resume", with: ["token": token], yielding: RideSession.self).values { return session }
            throw RideAPIError(status: 0, message: "The sign-in connection closed. Try again.")
        } catch { throw Self.apiError(error) }
    }

    func signOut(token: String) async throws {
        do { let _: Bool = try await client.mutation("accounts:signOut", with: ["token": token]) }
        catch { throw Self.apiError(error) }
    }

    func create(name: String) async throws -> RideSession {
        try await mutate("createRoom", args: ["name": name, "token": Self.freshToken()])
    }

    func join(code: String, role: DemoRole, name: String) async throws -> RideSession {
        try await mutate("joinRoom", args: ["code": code, "role": role.rawValue, "name": name, "token": Self.freshToken()])
    }

    func state(token: String) async throws -> RideRoomState {
        do {
            for try await state in client.subscribe(to: Self.module(for: token) + ":state", with: ["token": token], yielding: RideRoomState.self).values {
                return state
            }
            throw RideAPIError(status: 0, message: "The shared ride connection closed. Try again.")
        } catch { throw Self.apiError(error) }
    }

    func availability(token: String, online: Bool) async throws -> RideRoomState {
        try await mutate("availability", module: Self.module(for: token), args: ["token": token, "online": online])
    }

    func book(token: String, request: TripRequest) async throws -> RideRoomState {
        try await mutate("book", module: Self.module(for: token), args: ["token": token, "request": request])
    }

    func act(token: String, tripID: String, action: RideAction) async throws -> RideRoomState {
        try await mutate("act", module: Self.module(for: token), args: ["token": token, "tripID": tripID, "action": action])
    }

    func updates(token: String) -> AsyncThrowingStream<RideSyncEvent, Error> {
        AsyncThrowingStream { continuation in
            let state = client.subscribe(to: Self.module(for: token) + ":state", with: ["token": token], yielding: RideRoomState.self)
                .map(RideSyncEvent.state)
            let connection = connectionState
                .map(RideSyncEvent.connection)
                .setFailureType(to: ClientError.self)
            let subscription = state.merge(with: connection).sink { completion in
                switch completion {
                case .finished: continuation.finish()
                case .failure(let error): continuation.finish(throwing: Self.apiError(error))
                }
            } receiveValue: { event in
                continuation.yield(event)
            }
            continuation.onTermination = { _ in subscription.cancel() }
        }
    }

    private func mutate<T: Decodable>(_ name: String, module: String = "rides", args: [String: ConvexEncodable?]) async throws -> T {
        do { return try await client.mutation(module + ":" + name, with: args) }
        catch { throw Self.apiError(error) }
    }

    static func apiError(_ error: Error) -> RideAPIError {
        if let error = error as? RideAPIError { return error }
        struct Failure: Decodable { let status: Int; let message: String }
        if let error = error as? ClientError, case .ConvexError(let data) = error,
           let failure = try? JSONDecoder().decode(Failure.self, from: Data(data.utf8)),
           (400..<500).contains(failure.status) {
            return RideAPIError(status: failure.status, message: failure.message)
        }
        return RideAPIError(status: 0, message: "Couldn't reach the shared ride backend. Check your connection and try again.")
    }
}
