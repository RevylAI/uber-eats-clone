import SwiftUI

struct RideActivityView: View {
    @EnvironmentObject private var store: RideStore
    @State private var filter = "All"
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Activity").font(.system(size: 32, weight: .bold)).padding(.top, 12)
                Text("Upcoming").font(.title3.bold())
                if let trip = store.activeTrip {
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
                if trips.isEmpty { Text(store.connected ? "Your completed and cancelled demo rides will appear here." : "Connect a demo room to see shared trip history.").font(.subheadline).foregroundStyle(.secondary).padding(.vertical, 24) }
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
                DemoConnectionBadge().padding(.bottom, 15)
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
                        Text(store.displayName).font(.system(size: 30, weight: .bold))
                        Label("5.00 · Demo \(store.role.title.lowercased())", systemImage: "star.fill").font(.caption.bold()).padding(7).background(RideStyle.soft).clipShape(Capsule())
                    }
                    Spacer()
                    Image(systemName: "person.crop.circle.fill").font(.system(size: 62)).foregroundStyle(.gray.opacity(0.5))
                }.padding(.top, 15)
                HStack(spacing: 12) {
                    NavigationLink { RideHelpView() } label: { accountTile("Help", icon: "questionmark.circle.fill") }
                    NavigationLink { RideWalletView(payment: $store.defaultPayment) } label: { accountTile("Wallet", icon: "wallet.pass.fill") }
                    Button { store.tab = 2 } label: { accountTile("Activity", icon: "receipt.fill") }
                }.foregroundStyle(.black)
                Button { store.showConnection = true } label: {
                    HStack(spacing: 15) {
                        Image(systemName: "iphone.gen3.radiowaves.left.and.right").font(.system(size: 26))
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Rider & driver demo").font(.headline)
                            Text(store.connected ? "Share your room or view connection details" : "Connect two phones to the same room").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption)
                    }.padding(18).background(RideStyle.soft).clipShape(RoundedRectangle(cornerRadius: 12))
                }.foregroundStyle(.black)
                VStack(spacing: 0) {
                    NavigationLink { SavedRidePlacesView() } label: { accountRow("Saved places", icon: "star.fill") }
                    NavigationLink { RideSettingsView() } label: { accountRow("Settings", icon: "gearshape.fill") }
                    NavigationLink { RideInfoView(title: "Privacy", icon: "hand.raised.fill", text: "Demo names, trip details, and messages are stored within the private invitation room on your configured server. Session credentials stay in the iOS Keychain. Rooms expire after 24 hours; the database stays until its operator deletes it. No device location, contacts, payment details, or audio are collected.") } label: { accountRow("Privacy", icon: "lock.fill") }
                    NavigationLink { RideInfoView(title: "About this demo", icon: "info.circle.fill", text: "An independent SwiftUI ride demo inspired by Uber's rider workflows; not affiliated with Uber. Rider and driver share booking, acceptance, progress, and messages through a demo server. Maps, vehicles, prices, payment methods, and ratings are sample data. Eats remains a separate native app in this repository.") } label: { accountRow("About", icon: "info.circle.fill") }
                }.foregroundStyle(.black)
                DemoConnectionBadge()
                Text("Rides Demo 0.1 · No real rides or charges").font(.caption2).foregroundStyle(.secondary)
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
                    Text("Demo Wallet").font(.headline)
                    Text("$50.00").font(.system(size: 40, weight: .bold))
                    Text("Example balance only. No funds are stored, added, or deducted.").font(.caption)
                }.padding(24).frame(maxWidth: .infinity, alignment: .leading).background(Color(red: 0.86, green: 0.94, blue: 0.89)).clipShape(RoundedRectangle(cornerRadius: 14))
                Text("Payment methods").font(.title2.bold())
                ForEach(DemoPayment.allCases) { method in
                    Button { payment = method } label: {
                        HStack(spacing: 15) { Image(systemName: method.icon).frame(width: 25); Text(method.rawValue).font(.subheadline.bold()); Spacer(); Image(systemName: payment == method ? "checkmark.circle.fill" : "circle").font(.system(size: 23)) }.padding(.vertical, 16).foregroundStyle(.black)
                    }
                    Divider()
                }
                Label("Test methods only", systemImage: "lock.shield.fill").font(.headline)
                Text("No card entry or real payment processing is enabled. The selected method appears on the demo booking and receipt.").foregroundStyle(.secondary)
            }.padding(20)
        }.navigationTitle("Wallet").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar).tint(.black)
    }
}

struct SavedRidePlacesView: View {
    @EnvironmentObject private var store: RideStore
    @State private var add = false
    var body: some View {
        List {
            Section("Your saved demo locations") {
                ForEach(store.savedPlaces) { place in RideLocationRow(place: place, icon: "star.fill") }
                    .onDelete { store.savedPlaces.remove(atOffsets: $0) }
            }
            Button { add = true } label: { Label("Add a saved place", systemImage: "plus") }
            Section { Text("Choose from the offline demo catalog. Swipe to remove a place. Saved locations stay on this phone.").font(.caption).foregroundStyle(.secondary) }
        }.navigationTitle("Saved places").navigationBarTitleDisplayMode(.inline).sheet(isPresented: $add) { PlaceSearchView(title: "Save a place") { store.savePlace($0) }.environmentObject(store) }.tint(.black)
    }
}

struct RideSettingsView: View {
    @EnvironmentObject private var store: RideStore
    var body: some View {
        Form {
            Section("Profile") { LabeledContent("Name", value: store.displayName); LabeledContent("Mode", value: store.role.title); Text("Choose your name and mode before joining a room in Demo connection.").font(.caption).foregroundStyle(.secondary) }
            Section("Preferences") { Toggle("Show reservation reminder in app", isOn: $store.rideReminders).tint(.black); Text("In-app reminder only. No push notifications are sent.").font(.caption).foregroundStyle(.secondary) }
            Section("Demo") { Button("Demo connection & invitation") { store.showConnection = true }; NavigationLink("About the demo") { RideInfoView(title: "Demo limitations", icon: "car.side.fill", text: "Driver movement and travel estimates are simulated. The driver manually marks arrival, start, and completion. Reservations appear immediately, and demo payments never move money. No third-party login, SMS, geocoding, real dispatch, or emergency service is used.") } }
        }.navigationTitle("Settings").navigationBarTitleDisplayMode(.inline).tint(.black)
    }
}

struct RideHelpView: View {
    @EnvironmentObject private var store: RideStore
    var body: some View {
        List {
            Section("Your last trip") {
                if let trip = store.state?.trips.first { NavigationLink { TripTrackingView(tripID: trip.id) } label: { VStack(alignment: .leading, spacing: 7) { Text(trip.destination.name).font(.headline); Text(RideCatalog.date(trip.createdAt)).font(.caption).foregroundStyle(.secondary) } } }
                else { Text("No trips in this demo room yet.").foregroundStyle(.secondary) }
            }
            Section("Help topics") {
                NavigationLink("Connecting the two phones") { RideInfoView(title: "Connect your demo", icon: "iphone.gen3.radiowaves.left.and.right", text: "Start the shared server at an HTTPS address reachable from both phones. On the rider phone, open Account → Rider & driver demo, enter the server, and create a room. Share that private invitation with the other phone, choose Driver, join the room, and tap GO. A rider booking then appears on the driver phone.") }
                NavigationLink("Trip progress and reservations") { RideInfoView(title: "Demo ride progress", icon: "car.side.fill", text: "The driver accepts, marks arrival, starts, and completes the ride. Each committed state appears on the rider phone after its next sync, normally within a second. Nothing auto-accepts or advances a trip. Reserved rides carry their pickup time but can be manually advanced immediately for demos.") }
                NavigationLink("Payments and receipts") { RideInfoView(title: "Demo payments", icon: "creditcard.fill", text: "All fares, tips, and payment methods are simulated. A receipt records the chosen method and amount, but no bank or payment provider is charged. Do not enter real card information.") }
                NavigationLink("Connection problems") { RideInfoView(title: "Connection problems", icon: "wifi.exclamationmark", text: "Both phones need access to the same running server. If it stops or the preview workspace sleeps, the app shows a connection error and keeps its last synced state. Restart the server and tap Retry. Expired rooms need a new invitation.") }
            }
            Section { Text("No real support requests, lost-item claims, or emergency calls are submitted from this app.").font(.caption).foregroundStyle(.secondary) }
        }.navigationTitle("Help").navigationBarTitleDisplayMode(.inline).tint(.black)
    }
}
