#if canImport(UIKit) && !SWIFT_PACKAGE
import SwiftUI
import UIKit
import XCTest
@testable import RidesDemo

@MainActor
final class RidePasswordFocusTests: XCTestCase {
    func testNativePasswordKeepsFocusDuringSwiftUIUpdates() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.windows.first(where: \.isKeyWindow)
        let suite = "RidePasswordFocusTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let store = RideStore(defaults: defaults, vault: EmptyPasswordFocusVault())
        let host = UIHostingController(rootView: AccountSignInView().environmentObject(store))
        let window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            previousWindow?.makeKeyAndVisible()
            defaults.removePersistentDomain(forName: suite)
        }
        host.view.layoutIfNeeded()
        try await Task.sleep(nanoseconds: 200_000_000)
        let field = try XCTUnwrap(passwordField(in: host.view))
        XCTAssertTrue(field.becomeFirstResponder())
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertTrue(field.isFirstResponder, "SwiftUI updates must not dismiss the native password keyboard")
        field.insertText("starter")
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertTrue(field.isFirstResponder)
        XCTAssertEqual(field.text, "starter")
        field.resignFirstResponder()
    }

    private func passwordField(in view: UIView) -> UITextField? {
        if let field = view as? UITextField, field.accessibilityIdentifier == "auth.password" { return field }
        return view.subviews.lazy.compactMap { self.passwordField(in: $0) }.first
    }
}

private struct EmptyPasswordFocusVault: RideSessionVault {
    func load() -> StoredRideSession? { nil }
    func save(_ session: StoredRideSession) {}
    func clear() {}
}
#endif
