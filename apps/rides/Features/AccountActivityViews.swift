import SwiftUI

struct RideActivityView: View {
    @EnvironmentObject private var store: RideStore
    @State private var filter = "All"
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Activity").font(.system(size: 32, weight: .bold)).padding(.top, 12)
                Text("Upcoming").font(.title3.bold())
                if let trip = store.ownedActiveTrip {
                    NavigationLink { TripTrackingView(tripID: trip.id) } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(trip.destination.name).font(.headline)
                            Text(trip.status.title).font(.subheadline).foregroundStyle(RideStyle.green)
                            if let date = trip.scheduledAt { Text(RideCatalog.date(date)).font(.caption) }
                            Label("View ride", systemImage: "arrow.right").font(.caption.bold())
                        }.padding(18).frame(maxWidth: .infinity, alignment: .leading).overlay { RoundedRectangle(cornerRadius: 12).stroke(.gray.opacity(0.25)) }
                    }.foregroundStyle(.black)
                } else {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("You have no upcoming trips").font(.headline)
                            if store.role == .rider { Button("Reserve your ride →") { store.beginBooking(reserve: true) }.font(.subheadline) }
                            else { Text("Go online to receive new requests.").font(.subheadline).foregroundStyle(.secondary) }
                        }
                        Spacer()
                        Image(systemName: "calendar.badge.clock").font(.system(size: 32)).foregroundStyle(.gray)
                    }.padding(18).overlay { RoundedRectangle(cornerRadius: 12).stroke(.gray.opacity(0.25)) }
                }
                HStack {
                    Text("Past").font(.title3.bold())
                    Spacer()
                    Menu { Picker("Show trips", selection: $filter) { ForEach(["All", "Completed", "Cancelled"], id: \.self) { Text($0).tag($0) } } } label: { Image(systemName: "line.3.horizontal.decrease").padding(9).background(RideStyle.soft).clipShape(Circle()) }.accessibilityLabel("Filter trips")
                }
                let trips = store.pastTrips.filter { filter == "All" || (filter == "Completed" ? $0.status == .completed : $0.status == .cancelled) }
                if trips.isEmpty { Text("Your completed and cancelled rides will appear here.").font(.subheadline).foregroundStyle(.secondary).padding(.vertical, 24) }
                ForEach(trips) { trip in
                    VStack(alignment: .leading, spacing: 12) {
                        NavigationLink { TripTrackingView(tripID: trip.id) } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                DemoMapView().frame(height: 115).clipShape(RoundedRectangle(cornerRadius: 9))
                                Text(trip.destination.name).font(.headline).foregroundStyle(.black)
                                Text(RideCatalog.date(trip.createdAt)).font(.caption).foregroundStyle(.secondary)
                                Text("\(trip.status == .cancelled ? "$0.00" : RideCatalog.money(trip.totalCents)) · \(trip.status == .cancelled ? "Cancelled" : trip.serviceTitle)").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        if store.role == .rider {
                            Button { store.beginBooking(destination: trip.destination); store.draft.pickup = trip.pickup; store.draft.service = RideService(rawValue: trip.service) ?? .uberX; store.draft.stops = trip.stops } label: { Label("Rebook", systemImage: "arrow.clockwise").font(.caption.bold()).padding(9).background(RideStyle.soft).clipShape(Capsule()) }.foregroundStyle(.black)
                        }
                    }.padding(14).overlay { RoundedRectangle(cornerRadius: 12).stroke(.gray.opacity(0.18)) }
                }
            }.padding(20)
        }.navigationBarTitleDisplayMode(.inline).tint(.black)
    }
}

struct RideAccountView: View {
    @EnvironmentObject private var store: RideStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(store.account?.name ?? store.displayName).font(.system(size: 30, weight: .bold))
                        Text(store.role.title).font(.caption.bold()).padding(7).background(RideStyle.soft).clipShape(Capsule())
                        if let email = store.account?.email { Text(email).font(.subheadline).foregroundStyle(.secondary) }
                    }
                    Spacer()
                    Image(systemName: "person.crop.circle.fill").font(.system(size: 62)).foregroundStyle(.gray.opacity(0.5))
                }.padding(.top, 15)
                HStack(spacing: 12) {
                    NavigationLink { RideHelpView() } label: { accountTile("Help", icon: "questionmark.circle.fill") }
                    NavigationLink { RideWalletView(payment: $store.defaultPayment) } label: { accountTile("Wallet", icon: "wallet.pass.fill") }
                    Button { store.tab = 2 } label: { accountTile("Activity", icon: "receipt.fill") }
                }.foregroundStyle(.black)
                VStack(spacing: 0) {
                    NavigationLink { SavedRidePlacesView() } label: { accountRow("Saved places", icon: "star.fill") }
                    NavigationLink { RideSettingsView() } label: { accountRow("Settings", icon: "gearshape.fill") }
                    NavigationLink { RideInfoView(title: "Privacy", icon: "hand.raised.fill", text: "Your profile, trip details, and messages are associated with your account. Sign-in credentials are stored in the iOS Keychain. Avoid sharing sensitive personal or payment information in messages.") } label: { accountRow("Privacy", icon: "lock.fill") }
                    NavigationLink { RideInfoView(title: "About Rides", icon: "info.circle.fill", text: "Rides is an independent app for requesting rides and coordinating trip progress. Maps show an Austin route illustration, not live GPS. Driver identity and vehicle details are not independently verified. Payment processing, payouts, phone calls, and emergency response are unavailable. Reservations record a requested pickup time; automatic timed dispatch is unavailable.") } label: { accountRow("About", icon: "info.circle.fill") }
                }.foregroundStyle(.black)
                Button("Sign out") { Task { await store.signOut() } }.font(.subheadline.bold()).disabled(store.busy)
                Text("Rides 0.1").font(.caption2).foregroundStyle(.secondary)
            }.padding(20)
        }.navigationBarTitleDisplayMode(.inline).tint(.black)
    }
    private func accountTile(_ title: String, icon: String) -> some View {
        VStack(spacing: 12) { Image(systemName: icon).font(.system(size: 26)); Text(title).font(.subheadline.bold()) }.frame(maxWidth: .infinity).padding(.vertical, 22).background(RideStyle.soft).clipShape(RoundedRectangle(cornerRadius: 12))
    }
    private func accountRow(_ title: String, icon: String) -> some View {
        HStack(spacing: 18) { Image(systemName: icon).frame(width: 24); Text(title).font(.system(size: 16, weight: .medium)); Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary) }.padding(.vertical, 20)
    }
}

struct RideWalletView: View {
    @Binding var payment: DemoPayment
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Payments unavailable", systemImage: "creditcard").font(.headline)
                    Text("No cards are authorized or charged. Funds cannot be added or transferred.").font(.subheadline)
                }.padding(24).frame(maxWidth: .infinity, alignment: .leading).background(Color(red: 0.86, green: 0.94, blue: 0.89)).clipShape(RoundedRectangle(cornerRadius: 14))
                Text("Payment preference").font(.title2.bold())
                ForEach(DemoPayment.allCases) { method in
                    Button { payment = method } label: {
                        HStack(spacing: 15) { Image(systemName: method.icon).frame(width: 25); Text(method.title).font(.subheadline.bold()); Spacer(); Image(systemName: payment == method ? "checkmark.circle.fill" : "circle").font(.system(size: 23)) }.padding(.vertical, 16).foregroundStyle(.black)
                    }
                    Divider()
                }
                Text("Your preference labels your booking and trip details. It does not connect a payment account.").foregroundStyle(.secondary)
            }.padding(20)
        }.navigationTitle("Wallet").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar).tint(.black)
    }
}

struct SavedRidePlacesView: View {
    @EnvironmentObject private var store: RideStore
    @State private var add = false
    var body: some View {
        List {
            Section("Your saved places") {
                ForEach(store.savedPlaces) { place in RideLocationRow(place: place, icon: "star.fill") }
                    .onDelete { store.savedPlaces.remove(atOffsets: $0) }
            }
            Button { add = true } label: { Label("Add a saved place", systemImage: "plus") }
            Section { Text("Swipe to remove a place. Saved locations stay on this phone.").font(.caption).foregroundStyle(.secondary) }
        }.navigationTitle("Saved places").navigationBarTitleDisplayMode(.inline).sheet(isPresented: $add) { PlaceSearchView(title: "Save a place") { store.savePlace($0) }.environmentObject(store) }.tint(.black)
    }
}

struct RideSettingsView: View {
    @EnvironmentObject private var store: RideStore
    var body: some View {
        Form {
            Section("Profile") {
                LabeledContent("Name", value: store.account?.name ?? store.displayName)
                if let email = store.account?.email { LabeledContent("Email", value: email) }
                LabeledContent("Account type", value: store.role.title)
                if store.role == .driver {
                    if let vehicle = store.account?.vehicle, !vehicle.isEmpty { LabeledContent("Vehicle", value: vehicle) }
                    if let plate = store.account?.plate, !plate.isEmpty { LabeledContent("License plate", value: plate) }
                }
            }
            Section("Preferences") { Toggle("Show reservation reminder in app", isOn: $store.rideReminders).tint(.black); Text("In-app reminder only. No push notifications are sent.").font(.caption).foregroundStyle(.secondary) }
        }.navigationTitle("Settings").navigationBarTitleDisplayMode(.inline).tint(.black)
    }
}

struct RideHelpView: View {
    @EnvironmentObject private var store: RideStore
    var body: some View {
        List {
            Section("Your last trip") {
                if let trip = store.state?.trips.first { NavigationLink { TripTrackingView(tripID: trip.id) } label: { VStack(alignment: .leading, spacing: 7) { Text(trip.destination.name).font(.headline); Text(RideCatalog.date(trip.createdAt)).font(.caption).foregroundStyle(.secondary) } } }
                else { Text("No trips yet.").foregroundStyle(.secondary) }
            }
            Section("Help topics") {
                NavigationLink("Trip progress and reservations") { RideInfoView(title: "Trip progress", icon: "car.side.fill", text: "Your driver accepts the request and updates the ride when they arrive, start, and finish. Maps are route illustrations and do not track live location. Reservations record your requested pickup time but do not guarantee availability or automatically dispatch a driver.") }
                NavigationLink("Payments and receipts") { RideInfoView(title: "Payments and receipts", icon: "creditcard.fill", text: "Payments and payouts are unavailable. Trip details record fares, tip preferences, and a payment label, but no payment account is connected, authorized, or charged.") }
                NavigationLink("Connection problems") { RideInfoView(title: "Connection problems", icon: "wifi.exclamationmark", text: "Check your internet connection and tap Retry if trip updates stop. If your session has expired, sign in again with your account.") }
                NavigationLink("Safety and assistance") { RideInfoView(title: "Safety and assistance", icon: "shield.lefthalf.filled", text: "Emergency response, phone calls, audio recording, and safety monitoring are unavailable. If you need emergency assistance, call your local emergency number outside this app. Driver identity and vehicle details are not independently verified. Support requests and lost-item claims cannot be submitted in the app.") }
            }
        }.navigationTitle("Help").navigationBarTitleDisplayMode(.inline).tint(.black)
    }
}
