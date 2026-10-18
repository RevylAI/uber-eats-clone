import SwiftUI

struct AccountView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showReset = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack(spacing: 16) {
                    Text(initials)
                        .font(.system(size: 25, weight: .bold))
                        .frame(width: 68, height: 68)
                        .background(EatsTheme.pale, in: Circle())
                    VStack(alignment: .leading, spacing: 5) {
                        Text(store.profile.name).font(.system(size: 27, weight: .bold))
                        NavigationLink { ProfileEditorView() } label: {
                            Text("Edit account").font(.subheadline.weight(.semibold)).foregroundStyle(EatsTheme.green)
                        }
                    }
                    Spacer(minLength: 0)
                }

                HStack(spacing: 12) {
                    NavigationLink { OrdersView() } label: { AccountShortcut(symbol: "receipt", title: "Orders") }
                    NavigationLink { FavoritesView() } label: { AccountShortcut(symbol: "heart", title: "Favorites") }
                    NavigationLink { DemoWalletView() } label: { AccountShortcut(symbol: "creditcard", title: "Wallet") }
                }
                .buttonStyle(.plain)

                NavigationLink { DemoMembershipView() } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "sparkles").font(.title).foregroundStyle(EatsTheme.green)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Uber One").font(.title3.bold())
                            Text(store.profile.uberOne ? "Your demo benefits are on" : "A little more delicious. A little less delivery.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.caption.bold())
                    }
                    .padding(20)
                    .background(EatsTheme.pale, in: RoundedRectangle(cornerRadius: 18))
                }
                .buttonStyle(.plain)

                VStack(spacing: 0) {
                    NavigationLink { AddressView() } label: {
                        AccountMenuRow(symbol: "mappin.and.ellipse", title: "Saved address", subtitle: store.profile.address)
                    }
                    Divider().padding(.leading, 52)
                    NavigationLink { DemoWalletView() } label: {
                        AccountMenuRow(symbol: "creditcard", title: "Payment", subtitle: store.profile.payment)
                    }
                    Divider().padding(.leading, 52)
                    Toggle(isOn: profileBinding(\.notifications)) {
                        HStack(spacing: 16) {
                            Image(systemName: "bell").font(.title3).frame(width: 26)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Notifications").font(.body.weight(.medium))
                                Text("Saved preference only; no push alerts.").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .tint(EatsTheme.green)
                    .padding(.vertical, 18)
                    Divider().padding(.leading, 52)
                    NavigationLink { DemoHelpView() } label: {
                        AccountMenuRow(symbol: "questionmark.circle", title: "Help", subtitle: "Answers and demo support")
                    }
                    Divider().padding(.leading, 52)
                    NavigationLink { DemoAboutView() } label: {
                        AccountMenuRow(symbol: "info.circle", title: "About this app", subtitle: "Independent, offline demo")
                    }
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 16) {
                    Label("Made for exploring, not ordering", systemImage: "iphone")
                        .font(.subheadline.weight(.semibold))
                    Text("Your account, favorites, and orders stay on this device. No real orders, payments, or messages are sent.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("Reset demo data", role: .destructive) { showReset = true }
                        .font(.subheadline.weight(.semibold))
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(EatsTheme.gray, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(20)
        }
        .background(.white)
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.large)
        .foregroundStyle(.black)
        .confirmationDialog("Reset all demo data?", isPresented: $showReset, titleVisibility: .visible) {
            Button("Reset demo", role: .destructive) { store.resetDemo() }
        } message: {
            Text("This removes your profile changes, favorites, cart, and order history from this device. This can’t be undone.")
        }
    }

    private var initials: String {
        let value = store.profile.name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined()
        return value.isEmpty ? "YOU" : value.uppercased()
    }

    private func profileBinding<Value>(_ keyPath: WritableKeyPath<DemoProfile, Value>) -> Binding<Value> {
        Binding(get: { store.profile[keyPath: keyPath] }, set: { value in
            var profile = store.profile
            profile[keyPath: keyPath] = value
            store.profile = profile
        })
    }
}

private struct AccountShortcut: View {
    let symbol: String
    let title: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 25, weight: .medium))
            Text(title).font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(EatsTheme.gray, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct AccountMenuRow: View {
    let symbol: String
    let title: String
    var subtitle: String? = nil

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: symbol).font(.title3).frame(width: 26)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.body.weight(.medium))
                if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
        }
        .padding(.vertical, 19)
        .contentShape(Rectangle())
    }
}

private struct ProfileEditorView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var email = ""

    var body: some View {
        Form {
            Section("Your details") {
                TextField("Full name", text: $name).textContentType(.name).autocorrectionDisabled()
                TextField("Email address", text: $email)
                    .textContentType(.emailAddress).keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
            }
            Section {
                BlackButton(title: "Save changes") {
                    var profile = store.profile
                    profile.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    profile.email = email.trimmingCharacters(in: .whitespacesAndNewlines)
                    store.profile = profile
                    dismiss()
                }
                .disabled(!validProfile)
                .opacity(validProfile ? 1 : 0.4)
                .listRowInsets(EdgeInsets())
            } footer: {
                Text("Saved on this device only. No account is created and no verification email is sent.")
            }
        }
        .navigationTitle("Edit account")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { name = store.profile.name; email = store.profile.email }
    }

    private var validProfile: Bool {
        let address = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = address.split(separator: "@", omittingEmptySubsequences: false)
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && parts.count == 2 && !parts[0].isEmpty && parts[1].contains(".")
            && !address.contains(where: \.isWhitespace)
    }
}

private struct DemoWalletView: View {
    @EnvironmentObject private var store: AppStore
    private let payments = DemoProfile.paymentMethods

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 44)).foregroundStyle(EatsTheme.green)
                    .padding(24).background(EatsTheme.pale, in: RoundedRectangle(cornerRadius: 20))
                Text("A wallet for your demo").font(.system(size: 28, weight: .bold))
                Text("Choose a sample payment method. These are fictional options, and you’ll never be charged. Don’t enter real card details.")
                    .foregroundStyle(.secondary)
                VStack(spacing: 0) {
                    ForEach(payments, id: \.self) { payment in
                        Button {
                            var profile = store.profile
                            profile.payment = payment
                            store.profile = profile
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: payment == "Demo Eats Cash" ? "banknote" : "creditcard").font(.title2)
                                Text(payment).font(.body.weight(.medium))
                                Spacer()
                                Image(systemName: store.profile.payment == payment ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(store.profile.payment == payment ? EatsTheme.green : .gray)
                            }
                            .padding(.vertical, 22)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(store.profile.payment == payment ? .isSelected : [])
                        if payment != payments.last { Divider() }
                    }
                }
                Label("Selection saved automatically on this device", systemImage: "checkmark.shield")
                    .font(.footnote).foregroundStyle(EatsTheme.green)
            }
            .padding(24)
        }
        .navigationTitle("Wallet")
        .navigationBarTitleDisplayMode(.large)
        .foregroundStyle(.black)
        .background(.white)
    }
}

private struct DemoMembershipView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                Image(systemName: "sparkles").font(.system(size: 52)).foregroundStyle(EatsTheme.green)
                Text("Good food.\nExtra perks.").font(.system(size: 40, weight: .bold)).tracking(-1.5)
                Text("Explore Uber One in demo mode.").font(.title3).foregroundStyle(.secondary)
                Label("$0 delivery fee in the demo cart", systemImage: "bag")
                    .font(.headline)
                Text("Turning this on removes the delivery fee from this app’s checkout calculation. Other demo fees still apply. This isn’t a real membership, subscription, or free trial.")
                    .foregroundStyle(.secondary)
                Toggle("Enable demo membership", isOn: Binding(get: { store.profile.uberOne }, set: { value in
                    var profile = store.profile
                    profile.uberOne = value
                    store.profile = profile
                }))
                .font(.headline).tint(EatsTheme.green)
                .padding(20).background(EatsTheme.pale, in: RoundedRectangle(cornerRadius: 16))
                Text("No billing. No renewal. Switch it off anytime.").font(.footnote).foregroundStyle(.secondary)
            }
            .padding(24)
        }
        .navigationTitle("Uber One")
        .navigationBarTitleDisplayMode(.inline)
        .background(.white)
        .foregroundStyle(.black)
    }
}

private struct DemoHelpView: View {
    @State private var showSupport = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("How can we help?").font(.system(size: 30, weight: .bold))
                Text("A few things to know about your offline food adventure.").foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 22) {
                    DisclosureGroup("Where is my order?") {
                        Text("Open Orders and select an order to see its saved status. Use “Advance demo status” to move it forward. There’s no real restaurant, courier, or live location behind the simulation.")
                            .font(.subheadline).foregroundStyle(.secondary).padding(.top, 10)
                    }
                    Divider()
                    DisclosureGroup("Can I cancel an order?") {
                        Text("You can cancel a demo order while it’s at Order confirmed. Open its tracking screen, choose Cancel order, and confirm. Cancellation isn’t available once preparation starts.")
                            .font(.subheadline).foregroundStyle(.secondary).padding(.top, 10)
                    }
                    Divider()
                    DisclosureGroup("Was I charged?") {
                        Text("No. All payments, prices, and receipts in this app are part of a local demo. No payment is processed and no food will arrive.")
                            .font(.subheadline).foregroundStyle(.secondary).padding(.top, 10)
                    }
                    Divider()
                    DisclosureGroup("How do I clear my information?") {
                        Text("Go to Account and choose Reset demo data. After you confirm, your saved profile changes, cart, favorites, and order history are removed from this app.")
                            .font(.subheadline).foregroundStyle(.secondary).padding(.top, 10)
                    }
                }
                .tint(EatsTheme.green)
                VStack(alignment: .leading, spacing: 14) {
                    Text("Try a support interaction").font(.headline)
                    Text("This only shows a local sample response. No message is sent, no ticket is created, and no support agent is connected.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    BlackButton(title: "Simulate support response") { showSupport = true }
                }
                .padding(20).background(EatsTheme.gray, in: RoundedRectangle(cornerRadius: 18))
            }
            .padding(24)
        }
        .navigationTitle("Help")
        .navigationBarTitleDisplayMode(.inline)
        .foregroundStyle(.black)
        .background(.white)
        .alert("Demo support response", isPresented: $showSupport) {
            Button("Got it", role: .cancel) {}
        } message: {
            Text("This is a sample reply generated by the app, not a person: Your demo orders are stored on this device. Open Orders to review a receipt or manually advance an order’s status. Nothing was sent.")
        }
    }
}

private struct DemoAboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: "fork.knife.circle.fill").font(.system(size: 64)).foregroundStyle(EatsTheme.green)
                Text("A taste of the experience.").font(.system(size: 32, weight: .bold))
                Text("An independent demo").font(.title3.bold())
                Text("This app is an independent educational demonstration. It is not affiliated with, endorsed by, or operated by Uber, Uber Eats, or any listed restaurant. Names and trademarks belong to their respective owners.")
                Text("No real-world services").font(.title3.bold())
                Text("Orders, payments, memberships, support, and delivery tracking are simulations. No food is purchased, no courier is dispatched, and no payment is processed. Prices and offers are demo content, not real offers.")
                Text("Your data stays local").font(.title3.bold())
                Text("Profile details, preferences, favorites, and order history are saved in this app’s local storage. Use sample information rather than sensitive personal details. You can clear saved data from Account → Reset demo data.")
                Label("Offline simulation · No live backend", systemImage: "wifi.slash")
                    .font(.footnote.weight(.semibold)).foregroundStyle(EatsTheme.green)
            }
            .padding(24)
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .foregroundStyle(.black)
        .background(.white)
    }
}

struct FavoritesView: View {
    @EnvironmentObject private var store: AppStore

    private var favorites: [Restaurant] {
        store.restaurants.filter { store.snapshot.favorites.contains($0.id) }
    }

    var body: some View {
        ScrollView {
            if favorites.isEmpty {
                ActivityEmptyState(symbol: "heart", title: "Keep the good stuff close", message: "Tap the heart on a restaurant to save it here for your next craving.", action: "Explore restaurants") {
                    store.selectedTab = 0
                }
            } else {
                LazyVStack(alignment: .leading, spacing: 24) {
                    Text("Your go-to spots, all in one place.").font(.subheadline).foregroundStyle(.secondary)
                    ForEach(favorites) { restaurant in
                        VStack(alignment: .leading, spacing: 12) {
                            NavigationLink { RestaurantView(restaurant: restaurant) } label: {
                                FoodImage(name: restaurant.image, height: 170)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .overlay(alignment: .bottomLeading) {
                                        if !restaurant.offer.isEmpty {
                                            Text(restaurant.offer).font(.caption.bold()).padding(.horizontal, 12).padding(.vertical, 8)
                                                .background(EatsTheme.pale, in: Capsule()).padding(12)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            HStack(alignment: .top) {
                                NavigationLink { RestaurantView(restaurant: restaurant) } label: {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(restaurant.name).font(.title3.bold())
                                        Text(restaurant.cuisine).font(.subheadline).foregroundStyle(.secondary)
                                        Text("\(restaurant.minutes) min · \(restaurant.deliveryFee.money) delivery fee")
                                            .font(.caption).foregroundStyle(.secondary)
                                        Label(restaurant.rating, systemImage: "star.fill").font(.caption.weight(.medium))
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                                Button { store.toggleFavorite(restaurant.id) } label: {
                                    Image(systemName: "heart.fill").font(.title3).foregroundStyle(EatsTheme.green)
                                        .frame(width: 44, height: 44).background(EatsTheme.pale, in: Circle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Remove \(restaurant.name) from favorites")
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Favorites")
        .navigationBarTitleDisplayMode(.large)
        .background(.white)
        .foregroundStyle(.black)
    }
}

struct OrdersView: View {
    @EnvironmentObject private var store: AppStore
    @State private var replacementOrder: DemoOrder?

    var body: some View {
        ScrollView {
            if store.snapshot.orders.isEmpty {
                ActivityEmptyState(symbol: "bag", title: "Your next great meal awaits", message: "Once you place a demo order, you’ll find its receipt and progress right here.", action: "Find something delicious") {
                    store.selectedTab = 0
                }
            } else {
                LazyVStack(alignment: .leading, spacing: 24) {
                    Label("Demo orders · Saved on this device", systemImage: "iphone")
                        .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    ForEach(store.snapshot.orders) { order in
                        VStack(alignment: .leading, spacing: 18) {
                            NavigationLink { OrderTrackingView(orderID: order.id) } label: {
                                HStack(alignment: .top, spacing: 14) {
                                    Image(order.restaurant.image).resizable().scaledToFill()
                                        .frame(width: 76, height: 76).clipShape(RoundedRectangle(cornerRadius: 12))
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(order.restaurant.name).font(.headline)
                                        Text(order.placedAt.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption).foregroundStyle(.secondary)
                                        Text("\(order.lines.reduce(0) { $0 + $1.quantity }) items · \(order.total.money)")
                                            .font(.subheadline).foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right").font(.caption.bold()).padding(.top, 5)
                                }
                            }
                            .buttonStyle(.plain)
                            HStack {
                                Label(orderStatusTitle(order), systemImage: order.stage.symbol)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(order.stage == .cancelled ? .secondary : EatsTheme.green)
                                Spacer()
                                Text(order.mode.rawValue).font(.caption).foregroundStyle(.secondary)
                            }
                            if let scheduledFor = order.scheduledFor {
                                Label("Scheduled: \(scheduledFor.formatted(date: .abbreviated, time: .shortened))", systemImage: "calendar")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            DisclosureGroup("View receipt") { OrderReceiptView(order: order).padding(.top, 16) }
                                .font(.subheadline.weight(.medium)).tint(.black)
                            Button {
                                if !store.reorder(order) { replacementOrder = order }
                            } label: {
                                Text("Reorder").font(.subheadline.bold()).frame(maxWidth: .infinity).padding(14)
                                    .background(EatsTheme.gray, in: RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(18)
                        .background(.white, in: RoundedRectangle(cornerRadius: 18))
                        .overlay { RoundedRectangle(cornerRadius: 18).stroke(Color.black.opacity(0.09)) }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Orders")
        .navigationBarTitleDisplayMode(.large)
        .foregroundStyle(.black)
        .background(.white)
        .confirmationDialog("Replace your current cart?", isPresented: Binding(get: { replacementOrder != nil }, set: { if !$0 { replacementOrder = nil } }), titleVisibility: .visible) {
            Button("Replace cart and reorder", role: .destructive) {
                if let order = replacementOrder { _ = store.reorder(order, replace: true) }
                replacementOrder = nil
            }
            Button("Keep current cart", role: .cancel) { replacementOrder = nil }
        } message: {
            Text("Your current items will be removed and replaced with this order. You can review the demo total before placing it.")
        }
    }
}

private struct ActivityEmptyState: View {
    let symbol: String
    let title: String
    let message: String
    let action: String
    let onAction: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: symbol).font(.system(size: 48, weight: .light)).foregroundStyle(EatsTheme.green)
                .frame(width: 112, height: 112).background(EatsTheme.pale, in: Circle())
            Text(title).font(.system(size: 27, weight: .bold)).multilineTextAlignment(.center)
            Text(message).font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center)
            BlackButton(title: action, action: onAction).padding(.top, 8)
        }
        .padding(28)
        .padding(.top, 64)
    }
}

private struct OrderReceiptView: View {
    let order: DemoOrder

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(order.lines) { line in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(line.quantity)×").font(.subheadline.weight(.semibold)).frame(minWidth: 24, alignment: .leading)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(line.item.name).font(.subheadline.weight(.medium))
                        if !line.options.isEmpty { Text(line.options.joined(separator: ", ")).font(.caption).foregroundStyle(.secondary) }
                        if !line.note.isEmpty { Text("Note: \(line.note)").font(.caption).foregroundStyle(.secondary) }
                    }
                    Spacer(minLength: 4)
                    Text(line.total.money).font(.subheadline).monospacedDigit()
                }
            }
            Divider()
            HStack { Text("Items subtotal"); Spacer(); Text(order.lines.reduce(0) { $0 + $1.total }.money) }
                .font(.subheadline)
            HStack { Text("Order total").bold(); Spacer(); Text(order.total.money).bold() }
            Text("Total includes any demo fees, tax, tip, and discounts applied at checkout. No payment was processed.")
                .font(.caption).foregroundStyle(.secondary)
            Label("Demo payment: \(order.payment)", systemImage: "creditcard")
                .font(.subheadline)
            Divider()
            Label(order.mode == .pickup ? "Pickup from \(order.restaurant.name)" : order.address, systemImage: order.mode == .pickup ? "storefront" : "mappin.and.ellipse")
                .font(.subheadline)
            if order.mode == .pickup {
                Text("Saved account address: \(order.address)").font(.caption).foregroundStyle(.secondary)
            } else {
                if !order.unit.isEmpty {
                    Text("Apartment / unit: \(order.unit)").font(.caption).foregroundStyle(.secondary)
                }
                if !order.instructions.isEmpty {
                    Text("Delivery instructions: \(order.instructions)").font(.caption).foregroundStyle(.secondary)
                }
                Text("\(order.speed.rawValue) delivery").font(.caption).foregroundStyle(.secondary)
            }
            if let scheduledFor = order.scheduledFor {
                Label("Scheduled for \(scheduledFor.formatted(date: .abbreviated, time: .shortened))", systemImage: "calendar")
                    .font(.subheadline)
            }
            Text("Order \(order.id.uuidString.prefix(8).uppercased()) · \(order.placedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct OrderTrackingView: View {
    @EnvironmentObject private var store: AppStore
    let orderID: UUID
    @State private var showCancellation = false

    private var order: DemoOrder? { store.snapshot.orders.first { $0.id == orderID } }

    var body: some View {
        ScrollView {
            if let order {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(spacing: 7) {
                        Image(systemName: "wifi.slash")
                        Text("OFFLINE SIMULATION").tracking(1)
                    }
                    .font(.system(size: 10, weight: .bold)).foregroundStyle(EatsTheme.green)
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .background(EatsTheme.pale, in: Capsule())

                    VStack(alignment: .leading, spacing: 8) {
                        Text(orderStatusTitle(order)).font(.system(size: 32, weight: .bold)).tracking(-0.8)
                        Text(statusDescription(order)).font(.subheadline).foregroundStyle(.secondary)
                    }

                    DemoRouteMap(stage: order.stage, pickup: order.mode == .pickup)
                        .frame(height: 245).clipShape(RoundedRectangle(cornerRadius: 20))
                        .accessibilityLabel("Illustrated demo route, not a real map or live location")
                    VStack(alignment: .leading, spacing: 16) {
                        Label { Text(order.restaurant.name).font(.headline) } icon: {
                            Image(systemName: "storefront.fill").foregroundStyle(EatsTheme.green)
                        }
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(order.mode == .pickup ? "Pickup at the restaurant" : "Deliver to").font(.caption).foregroundStyle(.secondary)
                                Text(order.mode == .pickup ? order.restaurant.name : order.address).font(.subheadline.weight(.medium))
                            }
                        } icon: {
                            Image(systemName: order.mode == .pickup ? "bag.fill" : "house.fill").foregroundStyle(EatsTheme.green)
                        }
                        if order.mode == .delivery {
                            if !order.unit.isEmpty {
                                Text("Apartment / unit: \(order.unit)").font(.subheadline).foregroundStyle(.secondary)
                            }
                            if !order.instructions.isEmpty {
                                Text(order.instructions).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        if let scheduledFor = order.scheduledFor {
                            Label("Scheduled for \(scheduledFor.formatted(date: .abbreviated, time: .shortened))", systemImage: "calendar")
                                .font(.subheadline.weight(.medium))
                        }
                        HStack {
                            Text(order.mode == .pickup ? "Pickup" : "\(order.speed.rawValue) delivery")
                            Spacer()
                            Text(order.total.money).bold()
                        }
                        .font(.subheadline)
                        Label("Demo payment: \(order.payment)", systemImage: "creditcard")
                            .font(.caption).foregroundStyle(.secondary)
                        Text("Illustration only. No real courier location or arrival estimate.")
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    Divider()
                    if order.stage == .cancelled {
                        Label("Cancelled in this demo", systemImage: "xmark.circle.fill").font(.headline)
                        Text("This order won’t progress further. No payment was taken or refunded.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(OrderStage.allCases.filter { $0 != .cancelled }.enumerated()), id: \.element.rawValue) { index, stage in
                                trackingStep(stage, index: index, order: order)
                            }
                        }
                    }

                    if order.stage.rawValue < OrderStage.delivered.rawValue {
                        VStack(alignment: .leading, spacing: 12) {
                            BlackButton(title: "Advance demo status") { store.advanceOrder(orderID) }
                            Text("You control this simulation. Status changes only when you tap, and progress is saved on this device.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if order.stage == .confirmed {
                        Button("Cancel order", role: .destructive) { showCancellation = true }
                            .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 6)
                    }
                    if order.stage == .delivered { ratingSection(order) }

                    DisclosureGroup("Order receipt") { OrderReceiptView(order: order).padding(.top, 18) }
                        .font(.headline).tint(.black)
                        .padding(18).background(EatsTheme.gray, in: RoundedRectangle(cornerRadius: 16))
                    NavigationLink { DemoHelpView() } label: {
                        Label("Need help?", systemImage: "questionmark.circle").font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                    }
                    .foregroundStyle(EatsTheme.green)
                }
                .padding(20)
            } else {
                ContentUnavailableView("Order not found", systemImage: "receipt", description: Text("This order may have been removed when the demo was reset."))
                    .padding(.top, 60)
            }
        }
        .navigationTitle("Your order")
        .navigationBarTitleDisplayMode(.inline)
        .foregroundStyle(.black)
        .background(.white)
        .confirmationDialog("Cancel this demo order?", isPresented: $showCancellation, titleVisibility: .visible) {
            Button("Cancel order", role: .destructive) { store.cancelOrder(orderID) }
            Button("Keep order", role: .cancel) {}
        } message: {
            Text("This action can’t be undone. It only cancels the local simulation; no restaurant will be contacted.")
        }
    }

    private func trackingStep(_ stage: OrderStage, index: Int, order: DemoOrder) -> some View {
        let completed = stage.rawValue <= order.stage.rawValue
        let current = stage == order.stage
        return HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 4) {
                Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 23)).foregroundStyle(completed ? EatsTheme.green : Color.gray.opacity(0.35))
                if index < 3 {
                    Rectangle().fill(completed ? EatsTheme.green.opacity(0.25) : Color.gray.opacity(0.15))
                        .frame(width: 2, height: 24)
                }
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(stepTitle(stage, pickup: order.mode == .pickup)).font(.subheadline.weight(current ? .bold : .medium))
                    .foregroundStyle(completed ? .black : .gray)
                if current { Text(stage == .delivered ? "Demo complete" : "Current demo step").font(.caption).foregroundStyle(EatsTheme.green) }
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }

    private func ratingSection(_ order: DemoOrder) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(order.rating == 0 ? "How was your demo order?" : "Thanks for your feedback").font(.title3.bold())
            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { rating in
                    Button { store.rateOrder(orderID, rating: rating) } label: {
                        Image(systemName: rating <= order.rating ? "star.fill" : "star")
                            .font(.system(size: 30)).foregroundStyle(EatsTheme.green)
                            .frame(minWidth: 40, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Rate \(rating) \(rating == 1 ? "star" : "stars")")
                    .accessibilityAddTraits(rating == order.rating ? .isSelected : [])
                }
            }
            Text(order.rating == 0 ? "Your rating stays on this device. It isn’t sent to the restaurant." : "\(order.rating) of 5 stars · Saved locally. Tap a star to change it.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .background(EatsTheme.pale, in: RoundedRectangle(cornerRadius: 16))
    }

    private func statusDescription(_ order: DemoOrder) -> String {
        switch order.stage {
        case .confirmed: return "Your demo order is saved. Let’s get things started."
        case .preparing: return "Imagining something delicious at \(order.restaurant.name)."
        case .onTheWay: return order.mode == .pickup ? "Your simulated meal is ready for collection." : "One step closer. This is an illustrated delivery, not a real trip."
        case .delivered: return "All done. Thanks for taking the demo for a spin."
        case .cancelled: return "Your demo order has been cancelled."
        }
    }
}

private func orderStatusTitle(_ order: DemoOrder) -> String {
    if order.mode == .pickup {
        if order.stage == .onTheWay { return "Ready for pickup" }
        if order.stage == .delivered { return "Picked up" }
    }
    return order.stage.title
}

private func stepTitle(_ stage: OrderStage, pickup: Bool) -> String {
    switch stage {
    case .confirmed: return "Order confirmed"
    case .preparing: return "Preparing your food"
    case .onTheWay: return pickup ? "Ready for pickup" : "On the way"
    case .delivered: return pickup ? "Picked up" : "Delivered"
    case .cancelled: return "Cancelled"
    }
}

private struct DemoRouteMap: View {
    let stage: OrderStage
    let pickup: Bool

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Canvas { context, size in
                    context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.91, green: 0.94, blue: 0.90)))
                    for column in 0..<5 {
                        for row in 0..<4 {
                            let rect = CGRect(x: CGFloat(column) * size.width / 4 - 30, y: CGFloat(row) * 76 - 28, width: size.width / 4 - 16, height: 58)
                            context.fill(Path(roundedRect: rect, cornerRadius: 10), with: .color(Color(red: 0.84, green: 0.89, blue: 0.82)))
                        }
                    }
                    var crossStreet = Path()
                    crossStreet.move(to: CGPoint(x: 0, y: size.height * 0.72))
                    crossStreet.addLine(to: CGPoint(x: size.width, y: size.height * 0.14))
                    context.stroke(crossStreet, with: .color(.white.opacity(0.9)), style: StrokeStyle(lineWidth: 20, lineCap: .round))
                    var route = Path()
                    route.move(to: CGPoint(x: size.width * 0.20, y: size.height * 0.30))
                    route.addLine(to: CGPoint(x: size.width * 0.45, y: size.height * 0.30))
                    route.addQuadCurve(to: CGPoint(x: size.width * 0.52, y: size.height * 0.39), control: CGPoint(x: size.width * 0.52, y: size.height * 0.30))
                    route.addLine(to: CGPoint(x: size.width * 0.52, y: size.height * 0.65))
                    route.addQuadCurve(to: CGPoint(x: size.width * 0.60, y: size.height * 0.72), control: CGPoint(x: size.width * 0.52, y: size.height * 0.72))
                    route.addLine(to: CGPoint(x: size.width * 0.82, y: size.height * 0.72))
                    context.stroke(route, with: .color(.white), style: StrokeStyle(lineWidth: 15, lineCap: .round, lineJoin: .round))
                    if !pickup {
                        context.stroke(route, with: .color(stage == .cancelled ? .gray : EatsTheme.green), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round, dash: stage == .confirmed ? [5, 7] : []))
                    }
                }
                mapPin("storefront.fill", color: .black)
                    .position(x: geometry.size.width * 0.20, y: geometry.size.height * 0.30)
                if !pickup {
                    mapPin("house.fill", color: EatsTheme.green)
                        .position(x: geometry.size.width * 0.82, y: geometry.size.height * 0.72)
                    if stage == .onTheWay {
                        mapPin("bicycle", color: EatsTheme.green)
                            .position(x: geometry.size.width * 0.52, y: geometry.size.height * 0.51)
                    }
                }
                VStack {
                    HStack {
                        Text("ILLUSTRATED ROUTE").font(.system(size: 9, weight: .bold)).tracking(1)
                            .padding(9).background(.white.opacity(0.95), in: Capsule())
                        Spacer()
                    }
                    Spacer()
                    HStack {
                        Spacer()
                        Text("Not a live map").font(.caption2.weight(.medium))
                            .padding(7).background(.white.opacity(0.95), in: Capsule())
                    }
                }
                .padding(12)
            }
        }
        .accessibilityElement(children: .ignore)
    }

    private func mapPin(_ symbol: String, color: Color) -> some View {
        Image(systemName: symbol).font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
            .frame(width: 42, height: 42).background(color, in: Circle())
            .overlay { Circle().stroke(.white, lineWidth: 3) }
            .shadow(color: .black.opacity(0.12), radius: 5, y: 3)
    }
}
