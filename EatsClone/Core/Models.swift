import Foundation
import SwiftUI

struct MenuItem: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let detail: String
    let price: Int
    let image: String
    let category: String
    let popular: Bool
}

struct Restaurant: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let cuisine: String
    let rating: String
    let minutes: String
    let deliveryFee: Int
    let image: String
    let offer: String
    let menu: [MenuItem]
}

struct CartLine: Identifiable, Codable, Equatable {
    var id = UUID()
    let item: MenuItem
    var quantity: Int
    let options: [String]
    let extraPrice: Int
    let note: String
    var unitPrice: Int { item.price + extraPrice }
    var total: Int { unitPrice * quantity }
}

enum DeliveryMode: String, Codable, CaseIterable { case delivery = "Delivery", pickup = "Pickup" }
enum DeliverySpeed: String, Codable, CaseIterable { case standard = "Standard", priority = "Priority", schedule = "Schedule" }
enum OrderStage: Int, Codable, CaseIterable {
    case confirmed, preparing, onTheWay, delivered, cancelled
    var title: String {
        switch self {
        case .confirmed: return "Order confirmed"
        case .preparing: return "Preparing your food"
        case .onTheWay: return "Your order is on its way"
        case .delivered: return "Enjoy every bite"
        case .cancelled: return "Order cancelled"
        }
    }
    var symbol: String {
        switch self {
        case .confirmed: return "checkmark.circle.fill"
        case .preparing: return "flame.fill"
        case .onTheWay: return "bicycle"
        case .delivered: return "bag.fill"
        case .cancelled: return "xmark.circle.fill"
        }
    }
}

struct DemoOrder: Identifiable, Codable {
    var id = UUID()
    let restaurant: Restaurant
    let lines: [CartLine]
    let total: Int
    let address: String
    let mode: DeliveryMode
    let placedAt: Date
    var scheduledFor: Date? = nil
    var payment: String = "Visa •••• 4242"
    var instructions: String = "Meet at my door"
    var unit: String = ""
    var speed: DeliverySpeed = .standard
    var stage: OrderStage = .confirmed
    var rating: Int = 0
}

struct DemoProfile: Codable {
    static let paymentMethods = ["Visa •••• 4242", "Mastercard •••• 5555", "Apple Pay (demo)", "Demo Eats Cash"]
    var name = "Alex Morgan"
    var email = "alex@example.com"
    var address = "425 Market St, San Francisco"
    var unit = ""
    var instructions = "Meet at my door"
    var payment = "Visa •••• 4242"
    var notifications = true
    var uberOne = false
}

struct LocalSnapshot: Codable {
    var profile = DemoProfile()
    var favorites: Set<String> = []
    var cart: [CartLine] = []
    var cartRestaurantID: String?
    var orders: [DemoOrder] = []
    var onboarded = false
}

extension Int {
    var money: String { (Double(self) / 100).formatted(.currency(code: "USD")) }
}

enum EatsTheme {
    static let green = Color(red: 0.02, green: 0.47, blue: 0.29)
    static let pale = Color(red: 0.91, green: 0.97, blue: 0.92)
    static let gray = Color(white: 0.95)
}

struct BlackButton: View {
    let title: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.system(size: 17, weight: .semibold)).frame(maxWidth: .infinity).padding(.vertical, 18)
                .foregroundStyle(.white).background(.black, in: RoundedRectangle(cornerRadius: 10))
        }.buttonStyle(.plain)
    }
}

struct FoodImage: View {
    let name: String
    var height: CGFloat = 180
    var body: some View {
        GeometryReader { proxy in
            Image(name).resizable().scaledToFill().frame(width: proxy.size.width, height: proxy.size.height).clipped()
        }.frame(height: height).accessibilityHidden(true)
    }
}
