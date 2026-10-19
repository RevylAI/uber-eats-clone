import Foundation

enum RevylAuthBypass {
    enum Outcome: Equatable {
        case ignored
        case rejected(String)
        case accepted(tab: Int)
    }

    static func validate(_ url: URL, environment: [String: String], arguments: [String], isTestBuild: Bool) -> Outcome {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == "eatsclone", components.host == "revyl-auth" else { return .ignored }
        guard isTestBuild else { return .rejected("Unavailable in production builds") }
        guard launchValue("EATSCLONE_AUTH_BYPASS_ENABLED", environment: environment, arguments: arguments) == "true" else {
            return .rejected("Session gate is disabled")
        }
        guard let expected = launchValue("EATSCLONE_AUTH_BYPASS_TOKEN", environment: environment, arguments: arguments), expected.count >= 32 else {
            return .rejected("Session token is missing or too short")
        }
        guard components.user == nil, components.password == nil, components.port == nil,
              components.path.isEmpty, components.fragment == nil else { return .rejected("Invalid sign-in link") }
        let items = components.queryItems ?? []
        guard items.count == 3, Set(items.map(\.name)) == Set(["token", "role", "redirect"]) else {
            return .rejected("Invalid sign-in parameters")
        }
        guard items.first(where: { $0.name == "token" })?.value == expected else { return .rejected("Invalid session token") }
        guard items.first(where: { $0.name == "role" })?.value == "buyer" else { return .rejected("Role is not allowed") }
        let tabs = ["/home": 0, "/browse": 1, "/orders": 2, "/account": 3]
        guard let redirect = items.first(where: { $0.name == "redirect" })?.value, let tab = tabs[redirect] else {
            return .rejected("Redirect is not allowed")
        }
        return .accepted(tab: tab)
    }

    private static func launchValue(_ name: String, environment: [String: String], arguments: [String]) -> String? {
        if let value = environment[name] { return value }
        guard let index = arguments.firstIndex(of: "-" + name), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }
}
