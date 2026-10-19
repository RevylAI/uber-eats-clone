import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct RideAPIError: LocalizedError, Equatable {
    let status: Int
    let message: String
    var errorDescription: String? { message }
}

protocol RideAPI {
    var baseURL: URL { get }
    func create(name: String) async throws -> RideSession
    func join(code: String, role: DemoRole, name: String) async throws -> RideSession
    func state(token: String) async throws -> RideRoomState
    func availability(token: String, online: Bool) async throws -> RideRoomState
    func book(token: String, request: TripRequest) async throws -> RideRoomState
    func act(token: String, tripID: String, action: RideAction) async throws -> RideRoomState
}

struct RideAPIClient: RideAPI {
    let baseURL: URL
    var session = URLSession.shared
    private struct Failure: Decodable { let error: String }

    static func validatedURL(_ text: String) throws -> URL {
        guard let parts = URLComponents(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              let url = parts.url, let host = parts.host, !host.isEmpty,
              parts.user == nil, parts.password == nil, parts.query == nil, parts.fragment == nil,
              parts.path.isEmpty || parts.path == "/",
              parts.scheme == "https" || (parts.scheme == "http" && ["localhost", "127.0.0.1", "[::1]"].contains(host)) else {
            throw RideAPIError(status: 0, message: "Enter the HTTPS address of your demo server, without a path. Localhost HTTP is allowed for development.")
        }
        return url
    }

    func create(name: String) async throws -> RideSession {
        struct Body: Encodable { let name: String }
        return try await send("POST", "v1/rooms", body: JSONEncoder().encode(Body(name: name)))
    }
    func join(code: String, role: DemoRole, name: String) async throws -> RideSession {
        struct Body: Encodable { let role: DemoRole; let name: String }
        return try await send("POST", "v1/rooms/\(code)/join", body: JSONEncoder().encode(Body(role: role, name: name)))
    }
    func state(token: String) async throws -> RideRoomState { try await send("GET", "v1/state", token: token) }
    func availability(token: String, online: Bool) async throws -> RideRoomState {
        struct Body: Encodable { let online: Bool }
        return try await send("POST", "v1/availability", token: token, body: JSONEncoder().encode(Body(online: online)))
    }
    func book(token: String, request: TripRequest) async throws -> RideRoomState {
        try await send("POST", "v1/trips", token: token, body: JSONEncoder().encode(request))
    }
    func act(token: String, tripID: String, action: RideAction) async throws -> RideRoomState {
        try await send("POST", "v1/trips/\(tripID)/actions", token: token, body: JSONEncoder().encode(action))
    }
    private func send<T: Decodable>(_ method: String, _ path: String, token: String? = nil, body: Data? = nil) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.httpBody = body
        request.timeoutInterval = 12
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw RideAPIError(status: 0, message: "The server didn't return an HTTP response.") }
        guard (200..<300).contains(response.statusCode) else {
            let message = (try? JSONDecoder().decode(Failure.self, from: data).error) ?? "The demo server couldn't complete this request."
            throw RideAPIError(status: response.statusCode, message: message)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
