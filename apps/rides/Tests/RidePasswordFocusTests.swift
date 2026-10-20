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

    func testVisibilityChangesPreserveTextAndMidStringCaret() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.windows.first(where: \.isKeyWindow)
        var text = ""
        var focused = true
        @MainActor func content(secure: Bool) -> RidePasswordField {
            RidePasswordField(text: Binding(get: { text }, set: { text = $0 }), focused: Binding(get: { focused }, set: { focused = $0 }), secure: secure, creating: true, returnKey: .go, onSubmit: {})
        }
        let host = UIHostingController(rootView: content(secure: false))
        let window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            previousWindow?.makeKeyAndVisible()
        }
        host.view.layoutIfNeeded()
        try await Task.sleep(nanoseconds: 200_000_000)
        let field = try XCTUnwrap(passwordField(in: host.view))
        XCTAssertTrue(field.becomeFirstResponder())
        field.insertText("starter")
        XCTAssertEqual(text, "starter")

        host.rootView = content(secure: true)
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertTrue(field === passwordField(in: host.view))
        XCTAssertTrue(field.isFirstResponder)
        field.insertText("b")
        XCTAssertEqual(text, "starterb")

        let caret = try XCTUnwrap(field.position(from: field.beginningOfDocument, offset: 3))
        field.selectedTextRange = field.textRange(from: caret, to: caret)
        host.rootView = content(secure: false)
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertTrue(field === passwordField(in: host.view))
        XCTAssertTrue(field.isFirstResponder)
        let selection = try XCTUnwrap(field.selectedTextRange)
        XCTAssertEqual(field.offset(from: field.beginningOfDocument, to: selection.start), 3)
        field.insertText("q")
        XCTAssertEqual(text, "staqrterb")

        host.rootView = content(secure: true)
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertTrue(field === passwordField(in: host.view))
        XCTAssertTrue(field.isFirstResponder)
        field.insertText("x")
        XCTAssertEqual(text, "staqxrterb")
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
