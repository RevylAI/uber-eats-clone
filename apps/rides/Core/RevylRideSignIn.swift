import Foundation

enum RevylRideSignIn {
    enum Outcome: Equatable {
        case ignored, rejected(String), accepted(DemoRole, Int)
    }
    static func launchValue(_ name: String, environment: [String: String] = ProcessInfo.processInfo.environment, arguments: [String] = ProcessInfo.processInfo.arguments) -> String? {
        if let value = environment[name] { return value }
        guard let index = arguments.firstIndex(of: "-" + name), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }
    static func validate(_ url: URL, environment: [String: String], arguments: [String], isTestBuild: Bool) -> Outcome {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false), parts.scheme == "ridesdemo", parts.host == "revyl-auth" else { return .ignored }
        guard isTestBuild else { return .rejected("Unavailable in production builds") }
        guard launchValue("RIDES_AUTH_BYPASS_ENABLED", environment: environment, arguments: arguments) == "true" else { return .rejected("Session gate is disabled") }
        guard let expected = launchValue("RIDES_AUTH_BYPASS_TOKEN", environment: environment, arguments: arguments), expected.count >= 32 else { return .rejected("Session token is missing or too short") }
        guard parts.user == nil, parts.password == nil, parts.port == nil, parts.path.isEmpty, parts.fragment == nil else { return .rejected("Invalid sign-in link") }
        let items = parts.queryItems ?? []
        guard items.count == 3, Set(items.map(\.name)) == Set(["token", "role", "redirect"]) else { return .rejected("Invalid sign-in parameters") }
        guard items.first(where: { $0.name == "token" })?.value == expected else { return .rejected("Invalid session token") }
        guard let value = items.first(where: { $0.name == "role" })?.value, let role = DemoRole(rawValue: value) else { return .rejected("Role is not allowed") }
        guard let redirect = items.first(where: { $0.name == "redirect" })?.value, let tab = ["/home": 0, "/services": 1, "/activity": 2, "/account": 3][redirect] else { return .rejected("Redirect is not allowed") }
        return .accepted(role, tab)
    }
}
