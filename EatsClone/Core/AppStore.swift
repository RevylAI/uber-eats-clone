import Foundation
import SwiftUI

@MainActor
final class AppStore: ObservableObject {
    @Published var snapshot: LocalSnapshot { didSet { persist() } }
    @Published var mode: DeliveryMode = .delivery
    @Published var speed: DeliverySpeed = .standard
    @Published var scheduledDate = Date().addingTimeInterval(3600)
    @Published var tip = 200
    @Published var promo = ""
    @Published var selectedTab = 0
    @Published var showCart = false
    @Published var activeOrderID: UUID?
    let restaurants = Catalog.restaurants
    private let defaults: UserDefaults
    private let key = "eats.local.snapshot.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if ProcessInfo.processInfo.arguments.contains("--reset-demo") { defaults.removeObject(forKey: key) }
        if let data = defaults.data(forKey: key), let saved = try? JSONDecoder().decode(LocalSnapshot.self, from: data) {
            snapshot = saved
        } else { snapshot = LocalSnapshot() }
    }

    var profile: DemoProfile {
        get { snapshot.profile }
        set { snapshot.profile = newValue }
    }
    var cart: [CartLine] { snapshot.cart }
    var cartRestaurant: Restaurant? { restaurants.first { $0.id == snapshot.cartRestaurantID } }
    var cartCount: Int { cart.reduce(0) { $0 + $1.quantity } }
    var subtotal: Int { cart.reduce(0) { $0 + $1.total } }
    var deliveryFee: Int { mode == .pickup || profile.uberOne || (cartRestaurant?.id == "sushi" && subtotal >= 2000) ? 0 : (cartRestaurant?.deliveryFee ?? 0) }
    var serviceFee: Int { mode == .pickup ? 0 : Int((Double(subtotal) * 0.08).rounded()) }
    var tax: Int { Int((Double(subtotal) * 0.0875).rounded()) }
    var discount: Int { promo.uppercased() == "WELCOME" ? min(500, subtotal) : 0 }
    var offerDiscount: Int {
        if cartRestaurant?.id == "burger" {
            return cart.filter { $0.item.id == "super-burger" }.reduce(0) { $0 + ($1.quantity / 2) * $1.item.price }
        }
        if cartRestaurant?.id == "pizza", subtotal >= 2500 { return 500 }
        return 0
    }
    var priorityFee: Int { mode == .delivery && speed == .priority ? 299 : 0 }
    var total: Int { max(0, subtotal + deliveryFee + serviceFee + tax + priorityFee + (mode == .delivery ? tip : 0) - discount - offerDiscount) }

    func toggleFavorite(_ id: String) {
        if snapshot.favorites.contains(id) { snapshot.favorites.remove(id) } else { snapshot.favorites.insert(id) }
    }

    func add(_ item: MenuItem, restaurant: Restaurant, quantity: Int, options: [String], extraPrice: Int, note: String, replace: Bool = false) -> Bool {
        guard quantity > 0 else { return false }
        if let existing = snapshot.cartRestaurantID, existing != restaurant.id, !cart.isEmpty {
            guard replace else { return false }
            snapshot.cart = []
        }
        snapshot.cartRestaurantID = restaurant.id
        if let index = snapshot.cart.firstIndex(where: { $0.item.id == item.id && $0.options == options && $0.note == note && $0.extraPrice == extraPrice }) {
            snapshot.cart[index].quantity += quantity
        } else {
            snapshot.cart.append(CartLine(item: item, quantity: quantity, options: options, extraPrice: extraPrice, note: note))
        }
        return true
    }

    func changeQuantity(_ id: UUID, by delta: Int) {
        guard let index = snapshot.cart.firstIndex(where: { $0.id == id }) else { return }
        snapshot.cart[index].quantity += delta
        snapshot.cart.removeAll { $0.quantity <= 0 }
        if cart.isEmpty { snapshot.cartRestaurantID = nil }
    }

    @discardableResult
    func placeOrder() -> UUID? {
        guard let restaurant = cartRestaurant, !cart.isEmpty, !profile.address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        if speed == .schedule && scheduledDate <= Date() { return nil }
        let order = DemoOrder(restaurant: restaurant, lines: cart, total: total, address: profile.address, mode: mode, placedAt: Date(), scheduledFor: speed == .schedule ? scheduledDate : nil, payment: profile.payment, instructions: profile.instructions, unit: profile.unit, speed: mode == .pickup && speed == .priority ? .standard : speed)
        snapshot.orders.insert(order, at: 0)
        snapshot.cart = []
        snapshot.cartRestaurantID = nil
        promo = ""
        activeOrderID = order.id
        return order.id
    }

    func advanceOrder(_ id: UUID) {
        guard let index = snapshot.orders.firstIndex(where: { $0.id == id }), snapshot.orders[index].stage.rawValue < OrderStage.delivered.rawValue else { return }
        snapshot.orders[index].stage = OrderStage(rawValue: snapshot.orders[index].stage.rawValue + 1) ?? .delivered
    }

    func cancelOrder(_ id: UUID) {
        guard let index = snapshot.orders.firstIndex(where: { $0.id == id }), snapshot.orders[index].stage == .confirmed else { return }
        snapshot.orders[index].stage = .cancelled
    }

    func rateOrder(_ id: UUID, rating: Int) {
        guard (1...5).contains(rating), let index = snapshot.orders.firstIndex(where: { $0.id == id }), snapshot.orders[index].stage == .delivered else { return }
        snapshot.orders[index].rating = rating
    }

    func reorder(_ order: DemoOrder, replace: Bool = false) -> Bool {
        guard cart.isEmpty || replace else { return false }
        snapshot.cart = order.lines.map { CartLine(item: $0.item, quantity: $0.quantity, options: $0.options, extraPrice: $0.extraPrice, note: $0.note) }
        snapshot.cartRestaurantID = order.restaurant.id
        showCart = true
        return true
    }

    func resetDemo() {
        snapshot = LocalSnapshot()
        activeOrderID = nil
        showCart = false
        selectedTab = 0
        mode = .delivery
        speed = .standard
        tip = 200
        promo = ""
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }
}
