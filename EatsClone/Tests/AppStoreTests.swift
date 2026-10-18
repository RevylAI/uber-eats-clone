import XCTest
@testable import EatsClone

@MainActor
final class AppStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite: String!
    private var store: AppStore!

    override func setUp() async throws {
        suite = "EatsCloneTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        store = AppStore(defaults: defaults)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suite)
        store = nil
        defaults = nil
    }

    private func addBurger(quantity: Int = 1) {
        let restaurant = store.restaurants[0]
        XCTAssertTrue(store.add(restaurant.menu[0], restaurant: restaurant, quantity: quantity, options: ["Regular"], extraPrice: 0, note: ""))
    }

    func testCartMergesOnlyMatchingCustomizations() {
        addBurger()
        addBurger()
        let restaurant = store.restaurants[0]
        XCTAssertTrue(store.add(restaurant.menu[0], restaurant: restaurant, quantity: 1, options: ["Large"], extraPrice: 200, note: "No onions"))
        XCTAssertEqual(store.cart.count, 2)
        XCTAssertEqual(store.cartCount, 3)
        XCTAssertEqual(store.subtotal, 3785)
    }

    func testCrossRestaurantCartRequiresConsent() {
        addBurger()
        let pizza = store.restaurants[1]
        XCTAssertFalse(store.add(pizza.menu[0], restaurant: pizza, quantity: 1, options: [], extraPrice: 0, note: ""))
        XCTAssertEqual(store.cartRestaurant?.id, "burger")
        XCTAssertTrue(store.add(pizza.menu[0], restaurant: pizza, quantity: 1, options: [], extraPrice: 0, note: "", replace: true))
        XCTAssertEqual(store.cartRestaurant?.id, "pizza")
        XCTAssertEqual(store.cartCount, 1)
    }

    func testRemovingLastItemClearsRestaurant() {
        addBurger()
        store.changeQuantity(store.cart[0].id, by: -1)
        XCTAssertTrue(store.cart.isEmpty)
        XCTAssertNil(store.cartRestaurant)
        XCTAssertNil(store.placeOrder())
    }

    func testCheckoutCalculatesCentsAndPickupRemovesDeliveryCosts() {
        addBurger()
        XCTAssertEqual(store.subtotal, 1195)
        XCTAssertEqual(store.serviceFee, 96)
        XCTAssertEqual(store.tax, 105)
        XCTAssertEqual(store.total, 1695)
        store.speed = .priority
        XCTAssertEqual(store.total, 1994)
        store.promo = "WELCOME"
        XCTAssertEqual(store.total, 1494)
        store.mode = .pickup
        XCTAssertEqual(store.deliveryFee, 0)
        XCTAssertEqual(store.serviceFee, 0)
        XCTAssertEqual(store.priorityFee, 0)
        XCTAssertEqual(store.total, 800)
    }

    func testMembershipAndRestaurantOffersApply() {
        addBurger(quantity: 2)
        XCTAssertEqual(store.offerDiscount, 1195)
        store.profile.uberOne = true
        XCTAssertEqual(store.deliveryFee, 0)
        store.promo = "INVALID"
        XCTAssertEqual(store.discount, 0)
    }

    func testOrderSnapshotsCheckoutAndPersistsAcrossLaunches() {
        addBurger()
        store.profile.address = "100 Demo Street"
        store.profile.instructions = "Leave with concierge"
        store.speed = .schedule
        store.scheduledDate = Date().addingTimeInterval(7200)
        let expectedTotal = store.total
        let id = store.placeOrder()
        XCTAssertNotNil(id)
        XCTAssertTrue(store.cart.isEmpty)
        let restored = AppStore(defaults: defaults)
        let order = restored.snapshot.orders[0]
        XCTAssertEqual(order.id, id)
        XCTAssertEqual(order.total, expectedTotal)
        XCTAssertEqual(order.address, "100 Demo Street")
        XCTAssertEqual(order.instructions, "Leave with concierge")
        XCTAssertNotNil(order.scheduledFor)
        XCTAssertEqual(order.lines.count, 1)
    }

    func testTrackingStopsAtTerminalStates() {
        addBurger()
        let id = store.placeOrder()!
        store.advanceOrder(id)
        store.cancelOrder(id)
        XCTAssertEqual(store.snapshot.orders[0].stage, .preparing)
        store.advanceOrder(id)
        store.advanceOrder(id)
        store.advanceOrder(id)
        XCTAssertEqual(store.snapshot.orders[0].stage, .delivered)
        store.rateOrder(id, rating: 5)
        XCTAssertEqual(store.snapshot.orders[0].rating, 5)
    }

    func testCancellationAndReorderRequireCartConsent() {
        addBurger()
        let id = store.placeOrder()!
        store.cancelOrder(id)
        store.advanceOrder(id)
        XCTAssertEqual(store.snapshot.orders[0].stage, .cancelled)
        let order = store.snapshot.orders[0]
        addBurger()
        XCTAssertFalse(store.reorder(order))
        XCTAssertTrue(store.reorder(order, replace: true))
        XCTAssertEqual(store.cart.count, 1)
        XCTAssertNotEqual(store.cart[0].id, order.lines[0].id)
    }

    func testInvalidCheckoutDoesNotCreateOrder() {
        addBurger()
        store.profile.address = "   "
        XCTAssertNil(store.placeOrder())
        store.profile.address = "Demo address"
        store.speed = .schedule
        store.scheduledDate = Date().addingTimeInterval(-60)
        XCTAssertNil(store.placeOrder())
        XCTAssertEqual(store.cartCount, 1)
    }

    func testFavoritesAndResetPersist() {
        store.toggleFavorite("burger")
        XCTAssertTrue(AppStore(defaults: defaults).snapshot.favorites.contains("burger"))
        store.snapshot.onboarded = true
        addBurger()
        store.resetDemo()
        let restored = AppStore(defaults: defaults)
        XCTAssertFalse(restored.snapshot.onboarded)
        XCTAssertTrue(restored.snapshot.favorites.isEmpty)
        XCTAssertTrue(restored.cart.isEmpty)
    }
}
