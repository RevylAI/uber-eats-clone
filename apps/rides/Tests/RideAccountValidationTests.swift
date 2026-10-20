import XCTest
@testable import RidesDemo

final class RideAccountValidationTests: XCTestCase {
    func testShortRegistrationPasswordExplainsTheMinimum() {
        let errors = validate(password: "123456789")
        XCTAssertEqual(errors[.password], "Use at least 12 characters for your password.")
    }

    func testPasswordLengthBoundaries() {
        XCTAssertNil(validate(password: String(repeating: "a", count: 12))[.password])
        XCTAssertNil(validate(password: String(repeating: "a", count: 128))[.password])
        XCTAssertNotNil(validate(password: String(repeating: "a", count: 129))[.password])
    }

    func testPasswordLengthMatchesBackendUTF16Counting() {
        XCTAssertNil(validate(password: String(repeating: "🚗", count: 6))[.password])
        XCTAssertNotNil(validate(password: String(repeating: "🚗", count: 65))[.password])
    }

    func testSignInDoesNotApplyNewAccountMinimum() {
        XCTAssertNil(validate(password: "existing", creating: false)[.password])
        XCTAssertNotNil(validate(password: "", creating: false)[.password])
        XCTAssertNotNil(validate(password: String(repeating: "a", count: 129), creating: false)[.password])
    }

    func testEmailNeedsAddressAndDomain() {
        for email in ["", "  ", "name", "name@", "name@example", "two names@example.com"] {
            XCTAssertNotNil(validate(email: email)[.email], email)
        }
        XCTAssertNil(validate(email: "  Name@example.com  ")[.email])
    }

    func testNameMustBePresentAndWithinBackendLimit() {
        XCTAssertNotNil(validate(name: "  ")[.name])
        XCTAssertNil(validate(name: String(repeating: "n", count: 80))[.name])
        XCTAssertNotNil(validate(name: String(repeating: "n", count: 81))[.name])
    }

    func testDriverRequiresVehicleAndPlate() {
        let errors = validate(role: .driver)
        XCTAssertNotNil(errors[.vehicle])
        XCTAssertNotNil(errors[.plate])
        XCTAssertTrue(validate(role: .driver, vehicle: "Silver sedan", plate: "TX 123").isEmpty)
    }

    func testDriverMetadataLimitsMatchBackend() {
        XCTAssertNotNil(validate(role: .driver, vehicle: String(repeating: "v", count: 101), plate: "TX 123")[.vehicle])
        XCTAssertNotNil(validate(role: .driver, vehicle: "Sedan", plate: String(repeating: "p", count: 21))[.plate])
    }

    func testRiderDoesNotRequireDriverFields() {
        XCTAssertTrue(validate().isEmpty)
    }

    func testSignInDoesNotRequireRegistrationFields() {
        XCTAssertTrue(validate(name: "", creating: false, role: .driver).isEmpty)
    }

    private func validate(name: String = "Rider", email: String = "rider@example.invalid", password: String = "Synthetic-password", creating: Bool = true, role: DemoRole = .rider, vehicle: String = "", plate: String = "") -> [RideAccountField: String] {
        RideAccountValidation.errors(name: name, email: email, password: password, creating: creating, role: role, vehicle: vehicle, plate: plate)
    }
}
