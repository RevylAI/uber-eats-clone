import SwiftUI

struct CartView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        Group {
            if store.cart.isEmpty {
                ContentUnavailableView("Your cart is empty", systemImage: "bag", description: Text("Discover something delicious nearby."))
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text(store.cartRestaurant?.name ?? "Your cart").font(.title.bold())
                        ForEach(store.cart) { line in
                            HStack(alignment: .top, spacing: 14) {
                                FoodImage(name: line.item.image, height: 78).frame(width: 78).clipShape(RoundedRectangle(cornerRadius: 10))
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(line.item.name).font(.headline)
                                    Text(line.options.joined(separator: ", ")).font(.caption).foregroundStyle(.secondary)
                                    if !line.note.isEmpty { Text(line.note).font(.caption).foregroundStyle(.secondary) }
                                    Text(line.total.money).font(.subheadline)
                                    HStack(spacing: 18) {
                                        Button { store.changeQuantity(line.id, by: -1) } label: { Image(systemName: line.quantity == 1 ? "trash" : "minus") }.accessibilityLabel("Remove one \(line.item.name)")
                                        Text("\(line.quantity)").monospacedDigit()
                                        Button { store.changeQuantity(line.id, by: 1) } label: { Image(systemName: "plus") }.accessibilityLabel("Add one \(line.item.name)")
                                    }.font(.subheadline).padding(10).background(EatsTheme.gray, in: Capsule())
                                }
                                Spacer(minLength: 0)
                            }
                            Divider()
                        }
                        Button { dismiss() } label: { Label("Add more items", systemImage: "plus").font(.headline).padding(14).background(EatsTheme.gray, in: Capsule()) }
                        HStack { Text("Subtotal").font(.title3.bold()); Spacer(); Text(store.subtotal.money).font(.title3.bold()) }
                        Label("Made for this demo. No order will be sent.", systemImage: "checkmark.shield").font(.footnote).foregroundStyle(.secondary)
                    }.padding(20)
                }
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 12) {
                        Text("A little closer to something delicious").font(.footnote).frame(maxWidth: .infinity).padding(12).background(EatsTheme.pale)
                        NavigationLink { CheckoutView() } label: {
                            Text("Go to checkout").font(.headline).foregroundStyle(.white).frame(maxWidth: .infinity).padding(18).background(.black, in: RoundedRectangle(cornerRadius: 10))
                        }.padding(.horizontal, 20).padding(.bottom, 10)
                    }.background(.white)
                }
            }
        }.navigationTitle("Cart").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button { dismiss() } label: { Image(systemName: "xmark") }.accessibilityLabel("Close cart") } }
    }
}

struct CheckoutView: View {
    @EnvironmentObject private var store: AppStore
    @State private var addressSheet = false
    @State private var paymentSheet = false
    @State private var promoSheet = false
    @State private var confirmOrder = false
    @State private var promoText = ""
    @State private var promoError = false
    @State private var checkoutError = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Picker("Order type", selection: $store.mode) { ForEach(DeliveryMode.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
                LocalMapView().frame(height: 132).clipShape(RoundedRectangle(cornerRadius: 12))
                if store.mode == .delivery {
                    Button { addressSheet = true } label: {
                        checkoutRow("Home", subtitle: store.profile.address, icon: "house", trailing: true)
                    }
                    Button { addressSheet = true } label: {
                        checkoutRow(store.profile.instructions, subtitle: "Delivery instructions", icon: "person", trailing: true)
                    }
                } else {
                    checkoutRow(store.cartRestaurant?.name ?? "Restaurant", subtitle: "Demo pickup · 1.2 miles away", icon: "storefront", trailing: false)
                }
                Divider()
                Label(store.mode == .delivery ? "Delivery time" : "Pickup time", systemImage: "clock").font(.headline)
                HStack(spacing: 8) {
                    ForEach(DeliverySpeed.allCases.filter { store.mode == .delivery || $0 != .priority }, id: \.self) { speed in
                        Button { store.speed = speed } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(speed.rawValue).font(.subheadline.bold())
                                Text(speed == .schedule ? "Choose a time" : speed == .priority ? "15–25 min" : "25–40 min").font(.caption).foregroundStyle(.secondary)
                                Text(speed == .priority ? "+$2.99" : speed == .schedule ? "Plan ahead" : "No extra cost").font(.caption2)
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(12).frame(height: 100)
                                .background(.white, in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(store.speed == speed ? .black : Color(white: 0.88), lineWidth: store.speed == speed ? 2 : 1))
                        }.buttonStyle(.plain)
                    }
                }
                if store.speed == .schedule {
                    DatePicker("Scheduled for", selection: $store.scheduledDate, in: Date()...Date().addingTimeInterval(604800))
                }
                Divider()
                Text("Order summary").font(.title2.bold())
                ForEach(store.cart) { line in
                    HStack { Text("\(line.quantity) × \(line.item.name)").font(.subheadline); Spacer(); Text(line.total.money).font(.subheadline) }
                }
                Button { promoSheet = true } label: {
                    checkoutRow(store.discount > 0 ? "WELCOME applied" : "Add promo code", subtitle: "Try WELCOME for $5 off", icon: "tag", trailing: true)
                }
                if store.mode == .delivery {
                    Text("Add a tip").font(.headline)
                    Text("100% would go to your courier. This demo charges nothing.").font(.caption).foregroundStyle(.secondary)
                    HStack {
                        ForEach([0, 200, 400, 600], id: \.self) { amount in
                            Button { store.tip = amount } label: {
                                Text(amount == 0 ? "No tip" : amount.money).font(.subheadline.bold()).frame(maxWidth: .infinity).padding(13)
                                    .background(store.tip == amount ? Color.black : EatsTheme.gray, in: Capsule()).foregroundStyle(store.tip == amount ? .white : .black)
                            }
                        }
                    }
                }
                VStack(spacing: 13) {
                    priceRow("Subtotal", store.subtotal)
                    priceRow("Delivery fee", store.deliveryFee)
                    priceRow("Service fee", store.serviceFee)
                    priceRow("Estimated tax", store.tax)
                    if store.priorityFee > 0 { priceRow("Priority", store.priorityFee) }
                    if store.mode == .delivery { priceRow("Courier tip", store.tip) }
                    if store.discount > 0 { priceRow("Promo savings", -store.discount) }
                    if store.offerDiscount > 0 { priceRow("Restaurant offer", -store.offerDiscount) }
                    Divider()
                    HStack { Text("Total"); Spacer(); Text(store.total.money) }.font(.title3.bold())
                }
                Button { paymentSheet = true } label: {
                    checkoutRow(store.profile.payment, subtitle: "Demo payment method · no charge", icon: "creditcard", trailing: true)
                }
                Text("This is an independent offline simulation. Prices, availability, fees, and arrival times are sample data.").font(.caption).foregroundStyle(.secondary)
            }.padding(20)
        }.navigationTitle("Checkout").navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                BlackButton(title: "Place demo order · \(store.total.money)") { confirmOrder = true }.padding(20).background(.white)
            }
            .sheet(isPresented: $addressSheet) { NavigationStack { AddressView() } }
            .sheet(isPresented: $paymentSheet) { NavigationStack { PaymentPickerView() } }
            .sheet(isPresented: $promoSheet) {
                NavigationStack {
                    Form {
                        TextField("Promo code", text: $promoText).textInputAutocapitalization(.characters).autocorrectionDisabled()
                        Text("Use WELCOME for $5 off your demo order.").font(.footnote)
                        if promoError { Text("That code isn’t valid. Try WELCOME.").foregroundStyle(.red) }
                        Button("Apply code") {
                            let code = promoText.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                            if code == "WELCOME" { store.promo = code; promoError = false; promoSheet = false } else { promoError = true }
                        }
                    }.navigationTitle("Promo code").toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { promoSheet = false } } }
                }.presentationDetents([.medium])
            }
            .confirmationDialog("Place this simulated order?", isPresented: $confirmOrder, titleVisibility: .visible) {
                Button("Place demo order") {
                    if store.placeOrder() != nil { store.showCart = false } else { checkoutError = true }
                }
            } message: { Text("No payment will be taken and no restaurant will receive an order.") }
            .alert("Check your order details", isPresented: $checkoutError) {
                Button("OK", role: .cancel) { }
            } message: { Text("Add an address and make sure any scheduled time is still in the future.") }
    }

    private func checkoutRow(_ title: String, subtitle: String, icon: String, trailing: Bool) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).frame(width: 22)
            VStack(alignment: .leading, spacing: 4) { Text(title).font(.subheadline.weight(.semibold)); Text(subtitle).font(.caption).foregroundStyle(.secondary) }
            Spacer()
            if trailing { Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary) }
        }.foregroundStyle(.black).padding(.vertical, 6).frame(maxWidth: .infinity, alignment: .leading)
    }
    private func priceRow(_ title: String, _ amount: Int) -> some View {
        HStack { Text(title); Spacer(); Text(amount.money) }.font(.subheadline).foregroundStyle(amount < 0 ? EatsTheme.green : .secondary)
    }
}

struct AddressView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var address = ""
    @State private var unit = ""
    @State private var instructions = ""
    var body: some View {
        Form {
            Section("Delivery address") {
                TextField("Street address", text: $address).textContentType(.fullStreetAddress)
                TextField("Apartment, suite, or floor", text: $unit)
            }
            Section("Delivery instructions") {
                TextField("Meet at my door", text: $instructions, axis: .vertical)
            }
            Section {
                Button("Use demo home address") { address = "425 Market St, San Francisco" }
                Text("Addresses are saved on this device only. Location services and geocoding are stubbed.").font(.footnote).foregroundStyle(.secondary)
            }
        }.navigationTitle("Delivery details").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        store.profile.address = address.trimmingCharacters(in: .whitespacesAndNewlines)
                        store.profile.unit = unit
                        store.profile.instructions = instructions.isEmpty ? "Meet at my door" : instructions
                        dismiss()
                    }.bold().disabled(address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }.onAppear { address = store.profile.address; unit = store.profile.unit; instructions = store.profile.instructions }
    }
}

struct PaymentPickerView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        List {
            Section("Demo payment methods") {
                ForEach(DemoProfile.paymentMethods, id: \.self) { payment in
                    Button { store.profile.payment = payment; dismiss() } label: {
                        HStack { Label(payment, systemImage: "creditcard"); Spacer(); if store.profile.payment == payment { Image(systemName: "checkmark.circle.fill").foregroundStyle(EatsTheme.green) } }
                    }.foregroundStyle(.black)
                }
            }
            Section { Text("These are fictional methods. No card details are collected, and no payment provider is contacted.").font(.footnote).foregroundStyle(.secondary) }
        }.navigationTitle("Wallet").toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
    }
}

struct LocalMapView: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 0.91, green: 0.93, blue: 0.90)
                Canvas { context, size in
                    for i in -2...12 {
                        var path = Path()
                        path.move(to: CGPoint(x: CGFloat(i) * 55, y: 0))
                        path.addLine(to: CGPoint(x: CGFloat(i) * 55 + 90, y: size.height))
                        context.stroke(path, with: .color(.white), lineWidth: 12)
                    }
                    for i in 0...5 {
                        var path = Path()
                        path.move(to: CGPoint(x: 0, y: CGFloat(i) * 50))
                        path.addLine(to: CGPoint(x: size.width, y: CGFloat(i) * 50 - 50))
                        context.stroke(path, with: .color(.white), lineWidth: 9)
                    }
                    var route = Path()
                    route.move(to: CGPoint(x: size.width * 0.26, y: size.height * 0.70))
                    route.addLine(to: CGPoint(x: size.width * 0.45, y: size.height * 0.64))
                    route.addLine(to: CGPoint(x: size.width * 0.60, y: size.height * 0.32))
                    context.stroke(route, with: .color(EatsTheme.green), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                }
                Image(systemName: "house.fill").font(.title3).padding(12).foregroundStyle(.white).background(.black, in: Circle()).position(x: geo.size.width * 0.60, y: geo.size.height * 0.32)
                Image(systemName: "bag.fill").font(.subheadline).padding(10).foregroundStyle(.white).background(EatsTheme.green, in: Circle()).position(x: geo.size.width * 0.26, y: geo.size.height * 0.70)
                Text("ILLUSTRATIVE MAP").font(.system(size: 8, weight: .bold)).foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing).padding(8)
            }
        }.accessibilityLabel("Illustrative offline map between the restaurant and your home")
    }
}
