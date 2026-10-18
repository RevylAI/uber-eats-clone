import XCTest
@testable import EatsClone

final class RevylAuthBypassTests: XCTestCase {
    private let token = "test-fixture-only-not-a-real-session-token"

    private var environment: [String: String] {
        ["EATSCLONE_AUTH_BYPASS_ENABLED": "true", "EATSCLONE_AUTH_BYPASS_TOKEN": token]
    }

    private func link(token: String? = nil, role: String = "buyer", redirect: String = "/home") -> URL {
        var url = URLComponents(string: "eatsclone://revyl-auth")!
        url.queryItems = [URLQueryItem(name: "token", value: token ?? self.token), URLQueryItem(name: "role", value: role), URLQueryItem(name: "redirect", value: redirect)]
        return url.url!
    }

    func testAllowsOnlyBuyerAndSupportedTabs() {
        for (tab, route) in ["/home", "/browse", "/orders", "/account"].enumerated() {
            XCTAssertEqual(RevylAuthBypass.validate(link(redirect: route), environment: environment, arguments: [], isTestBuild: true), .accepted(tab: tab))
        }
    }

    func testAcceptsRevylIOSLaunchArguments() {
        let arguments = ["EatsClone", "-EATSCLONE_AUTH_BYPASS_ENABLED", "true", "-EATSCLONE_AUTH_BYPASS_TOKEN", token]
        XCTAssertEqual(RevylAuthBypass.validate(link(), environment: [:], arguments: arguments, isTestBuild: true), .accepted(tab: 0))
    }

    func testProductionBuildRejectsEvenValidSession() {
        XCTAssertEqual(RevylAuthBypass.validate(link(), environment: environment, arguments: [], isTestBuild: false), .rejected("Unavailable in production builds"))
    }

    func testMissingOrDisabledGateRejects() {
        for gate in [nil, "false", "1", "TRUE"] {
            var values = environment
            values["EATSCLONE_AUTH_BYPASS_ENABLED"] = gate
            XCTAssertEqual(RevylAuthBypass.validate(link(), environment: values, arguments: [], isTestBuild: true), .rejected("Session gate is disabled"))
        }
    }

    func testMissingShortOrIncorrectTokenRejects() {
        for expected in [nil, "", "short"] {
            var values = environment
            values["EATSCLONE_AUTH_BYPASS_TOKEN"] = expected
            XCTAssertEqual(RevylAuthBypass.validate(link(), environment: values, arguments: [], isTestBuild: true), .rejected("Session token is missing or too short"))
        }
        XCTAssertEqual(RevylAuthBypass.validate(link(token: "wrong-token"), environment: environment, arguments: [], isTestBuild: true), .rejected("Invalid session token"))
    }

    func testUnknownRoleOrRedirectRejects() {
        XCTAssertEqual(RevylAuthBypass.validate(link(role: "admin"), environment: environment, arguments: [], isTestBuild: true), .rejected("Role is not allowed"))
        for route in ["/admin", "//example.com", "https://example.com", "/home/..", "/home?next=/admin"] {
            XCTAssertEqual(RevylAuthBypass.validate(link(redirect: route), environment: environment, arguments: [], isTestBuild: true), .rejected("Redirect is not allowed"))
        }
    }

    func testDuplicateAndUnexpectedParametersReject() {
        for suffix in ["&token=other", "&role=admin", "&redirect=/admin", "&extra=value"] {
            let url = URL(string: link().absoluteString + suffix)!
            XCTAssertEqual(RevylAuthBypass.validate(url, environment: environment, arguments: [], isTestBuild: true), .rejected("Invalid sign-in parameters"))
        }
    }

    func testUnrelatedURLIsIgnored() {
        XCTAssertEqual(RevylAuthBypass.validate(URL(string: "https://example.com")!, environment: environment, arguments: [], isTestBuild: true), .ignored)
    }

    @MainActor
    func testRejectedLinkDoesNotChangeAppState() {
        let suite = "RevylAuthBypassTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = AppStore(defaults: defaults)
        let id = store.navigationResetID
        store.handleRevylAuthBypass(link(token: "wrong-token"), environment: environment, arguments: [])
        XCTAssertFalse(store.snapshot.onboarded)
        XCTAssertEqual(store.selectedTab, 0)
        XCTAssertEqual(store.navigationResetID, id)
        #if DEBUG
        XCTAssertEqual(store.revylSessionMessage, "Revyl sign-in rejected: Invalid session token")
        #else
        XCTAssertNil(store.revylSessionMessage)
        #endif
    }

    @MainActor
    func testAcceptedLinkUsesNormalPersistentOnboardingState() {
        let suite = "RevylAuthBypassTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = AppStore(defaults: defaults)
        store.handleRevylAuthBypass(link(redirect: "/orders"), environment: environment, arguments: [])
        #if DEBUG
        XCTAssertTrue(store.snapshot.onboarded)
        XCTAssertEqual(store.selectedTab, 2)
        XCTAssertTrue(AppStore(defaults: defaults).snapshot.onboarded)
        XCTAssertEqual(store.revylSessionMessage, "Revyl sign-in accepted · Local buyer")
        #else
        XCTAssertFalse(store.snapshot.onboarded)
        XCTAssertEqual(store.selectedTab, 0)
        XCTAssertNil(store.revylSessionMessage)
        #endif
    }
}
