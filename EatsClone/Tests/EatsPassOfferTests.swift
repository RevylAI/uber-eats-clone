import XCTest
@testable import EatsClone

final class EatsPassOfferTests: XCTestCase {
    private let member = ["EATSCLONE_FLAG_PASS_BADGE": "on", "EATSCLONE_ACCOUNT_TIER": "eats_pass"]

    func testHiddenWithoutFlagOrMembership() {
        XCTAssertEqual(EatsPassOffer.resolve(environment: [:], arguments: []), .hidden)
        XCTAssertEqual(EatsPassOffer.resolve(environment: ["EATSCLONE_FLAG_PASS_BADGE": "on", "EATSCLONE_ACCOUNT_TIER": "standard"], arguments: []), .hidden)
        XCTAssertEqual(EatsPassOffer.resolve(environment: ["EATSCLONE_FLAG_PASS_BADGE": "off", "EATSCLONE_ACCOUNT_TIER": "eats_pass"], arguments: []), .hidden)
    }

    func testVisibleForMembersWithServerDeliveryFlag() {
        XCTAssertEqual(EatsPassOffer.resolve(environment: member, arguments: []), .visible(freeDelivery: false))
        var withDelivery = member
        withDelivery["EATSCLONE_SERVER_FREE_DELIVERY"] = "on"
        XCTAssertEqual(EatsPassOffer.resolve(environment: withDelivery, arguments: []), .visible(freeDelivery: true))
    }

    func testReadsIOSLaunchArguments() {
        let arguments = ["-EATSCLONE_FLAG_PASS_BADGE", "on", "-EATSCLONE_ACCOUNT_TIER", "eats_pass"]
        XCTAssertEqual(EatsPassOffer.resolve(environment: [:], arguments: arguments), .visible(freeDelivery: false))
    }
}
