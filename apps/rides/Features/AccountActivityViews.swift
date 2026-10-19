import SwiftUI

struct RideActivityView: View {
    @EnvironmentObject private var store: RideStore
    @State private var filter = "All"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Activity")
                    .font(.system(size: 32, weight: .bold))
                    .tracking(-0.8)
                    .padding(.top, 12)

                if store.state == nil {
                    if store.errorMessage != nil {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Your trips couldn't be loaded.").font(.headline)
                            Text("Check your connection and try again.").font(.subheadline).foregroundStyle(.secondary)
                            Button("Try again") { Task { await store.sync() } }
                                .font(.subheadline.weight(.semibold))
                                .frame(minHeight: 44)
                                .disabled(store.busy)
                        }
                    } else {
                        ProgressView("Loading your trips…").frame(maxWidth: .infinity).padding(.vertical, 32)
                    }
                } else {
                    currentRide

                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Past rides").font(.system(size: 22, weight: .bold))
                            Spacer()
                            Menu {
                                Picker("Show trips", selection: $filter) {
                                    ForEach(["All", "Completed", "Cancelled"], id: \.self) { Text($0).tag($0) }
                                }
                            } label: {
                                HStack(spacing: 7) {
                                    Text(filter).font(.system(size: 13, weight: .semibold))
                                    Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold))
                                }
                                .padding(.horizontal, 14)
                                .frame(minHeight: 44)
                                .background(RideStyle.soft)
                                .clipShape(Capsule())
                            }
                            .accessibilityLabel("Filter trips, \(filter)")
                        }
                        let trips = store.pastTrips.filter {
                            filter == "All" || (filter == "Completed" ? $0.status == .completed : $0.status == .cancelled)
                        }.sorted { $0.createdAt > $1.createdAt }
                        if trips.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(filter == "All" ? "No past rides yet" : "No \(filter.lowercased()) rides")
                                    .font(.system(size: 17, weight: .semibold))
                                Text(filter == "All" ? "Completed and cancelled rides will appear here with their trip details." : "Try another filter to see your other rides.")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                                if filter != "All" {
                                    Button("Show all rides") { filter = "All" }
                                        .font(.subheadline.weight(.semibold))
                                        .frame(minHeight: 44)
                                }
                            }
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RideStyle.soft)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        ForEach(trips) { trip in
                            VStack(alignment: .leading, spacing: 12) {
                                NavigationLink { TripTrackingView(tripID: trip.id) } label: {
                                    HStack(alignment: .top, spacing: 12) {
                                        RideCarArt(service: RideService(rawValue: trip.service) ?? .uberX)
                                            .scaleEffect(0.7)
                                            .frame(width: 60, height: 48)
                                            .background(RideStyle.soft)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(trip.destination.name).font(.system(size: 17, weight: .semibold))
                                            Text("From \(trip.pickup.name)").font(.system(size: 13)).foregroundStyle(.secondary)
                                            Text(RideCatalog.date(trip.createdAt)).font(.system(size: 12)).foregroundStyle(.secondary)
                                            Text(trip.status == .cancelled ? "Cancelled" : "\(trip.serviceTitle) · Recorded \(RideCatalog.money(trip.totalCents))")
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer(minLength: 0)
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(.secondary)
                                            .padding(.top, 4)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                }
                                .accessibilityHint("View trip details")
                                if store.role == .rider {
                                    Button {
                                        store.beginBooking(destination: trip.destination)
                                        store.draft.pickup = trip.pickup
                                        store.draft.service = RideService(rawValue: trip.service) ?? .uberX
                                        store.draft.stops = trip.stops
                                    } label: {
                                        Label("Rebook", systemImage: "arrow.clockwise")
                                            .font(.system(size: 13, weight: .semibold))
                                            .padding(.horizontal, 16)
                                            .frame(minHeight: 44)
                                            .background(RideStyle.soft)
                                            .clipShape(Capsule())
                                    }
                                    .disabled(store.ownedActiveTrip != nil)
                                    .opacity(store.ownedActiveTrip == nil ? 1 : 0.45)
                                    .accessibilityLabel("Rebook ride to \(trip.destination.name)")
                                    .accessibilityHint(store.ownedActiveTrip == nil ? "Review the route and fare before requesting" : "Finish or cancel your current ride first")
                                }
                            }
                            .padding(.vertical, 8)
                            Divider()
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(.white)
        .foregroundStyle(.black)
        .buttonStyle(.plain)
        .navigationBarTitleDisplayMode(.inline)
        .tint(.black)
    }

    private var currentRide: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(store.ownedActiveTrip == nil ? "Up next" : "Current ride").font(.system(size: 22, weight: .bold))
            if let trip = store.ownedActiveTrip {
                NavigationLink { TripTrackingView(tripID: trip.id) } label: {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(trip.destination.name).font(.system(size: 20, weight: .bold))
                                Text(trip.status.title).font(.system(size: 14, weight: .semibold)).foregroundStyle(RideStyle.green)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right").font(.system(size: 17, weight: .semibold))
                        }
                        if let date = trip.scheduledAt {
                            Text("Requested pickup: \(RideCatalog.date(date))").font(.system(size: 13)).foregroundStyle(.secondary)
                        }
                        Text("View ride details").font(.system(size: 14, weight: .semibold))
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RideStyle.soft)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text(store.role == .rider ? "No upcoming rides" : "No active ride").font(.system(size: 17, weight: .semibold))
                    Text(store.role == .rider ? "Ready when you are. Choose a destination to get started." : "Open Home to manage your availability and view ride requests.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                    Button {
                        if store.role == .rider { store.beginBooking() }
                        else { store.tab = 0 }
                    } label: {
                        HStack(spacing: 8) {
                            Text(store.role == .rider ? "Find a ride" : "Go to Home")
                            Image(systemName: "arrow.right")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .frame(minHeight: 44)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RideStyle.soft)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }
}

struct RideAccountView: View {
    @EnvironmentObject private var store: RideStore
    @State private var confirmSignOut = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(store.account?.name ?? store.displayName)
                            .font(.system(size: 30, weight: .bold))
                            .tracking(-0.6)
                        Text(store.role.title)
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(RideStyle.soft)
                            .clipShape(Capsule())
                        if let email = store.account?.email {
                            Text(email).font(.system(size: 14)).foregroundStyle(.secondary).textSelection(.enabled)
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "person.fill")
                        .font(.system(size: 24))
                        .frame(width: 56, height: 56)
                        .background(RideStyle.soft)
                        .clipShape(Circle())
                        .accessibilityHidden(true)
                }
                .padding(.top, 16)

                HStack(spacing: 10) {
                    NavigationLink { RideHelpView() } label: { accountTile("Help", icon: "questionmark.circle") }
                    NavigationLink { RideWalletView(payment: $store.defaultPayment) } label: { accountTile("Wallet", icon: "wallet.pass") }
                    Button { store.tab = 2 } label: { accountTile("Activity", icon: "receipt") }
                }

                VStack(spacing: 0) {
                    NavigationLink { SavedRidePlacesView() } label: { accountRow("Saved places", icon: "bookmark") }
                    Divider().padding(.leading, 44)
                    NavigationLink { RideSettingsView() } label: { accountRow("Settings", icon: "gearshape") }
                    Divider().padding(.leading, 44)
                    NavigationLink {
                        RideInfoView(title: "Privacy", icon: "hand.raised", text: "Your profile, trip details, and messages are associated with your account. Sign-in credentials are stored in the iOS Keychain. Avoid sharing sensitive personal or payment information in messages.")
                    } label: { accountRow("Privacy", icon: "lock") }
                    Divider().padding(.leading, 44)
                    NavigationLink {
                        RideInfoView(title: "About Rides", icon: "info.circle", text: "Rides is an independent app for requesting rides and coordinating trip progress. Apple map tiles show straight-line route previews, not driving directions, live GPS, or a driver's current location. Driver identity and vehicle details are not independently verified. Payment processing, payouts, phone calls, and emergency response are unavailable. Reservations record a requested pickup time; automatic timed dispatch is unavailable.")
                    } label: { accountRow("About Rides", icon: "info.circle") }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Button { confirmSignOut = true } label: {
                        HStack {
                            if store.busy { ProgressView().tint(.black) }
                            Text(store.busy ? "Please wait…" : "Sign out").font(.system(size: 15, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(RideStyle.soft)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(store.busy || store.ownedActiveTrip != nil)
                    if store.ownedActiveTrip != nil {
                        Text("Finish or cancel your current ride before signing out.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text("Rides 0.1").font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(.white)
        .foregroundStyle(.black)
        .buttonStyle(.plain)
        .navigationBarTitleDisplayMode(.inline)
        .tint(.black)
        .confirmationDialog("Sign out of Rides?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) { Task { await store.signOut() } }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func accountTile(_ title: String, icon: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 23, weight: .medium)).accessibilityHidden(true)
            Text(title).font(.system(size: 14, weight: .semibold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(RideStyle.soft)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func accountRow(_ title: String, icon: String) -> some View {
        HStack(spacing: 20) {
            Image(systemName: icon).font(.system(size: 20)).frame(width: 24).accessibilityHidden(true)
            Text(title).font(.system(size: 16, weight: .medium))
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
        }
        .frame(minHeight: 62)
        .contentShape(Rectangle())
    }
}

struct RideWalletView: View {
    @Binding var payment: DemoPayment

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Payments unavailable", systemImage: "creditcard").font(.system(size: 17, weight: .semibold))
                    Text("No cards are connected or charged. Funds cannot be added or transferred.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RideStyle.soft)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Payment preference").font(.system(size: 24, weight: .bold))
                    Text("Choose a label for future bookings. This does not connect a payment account or arrange payment.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 0) {
                    ForEach(DemoPayment.allCases) { method in
                        Button { payment = method } label: {
                            HStack(spacing: 14) {
                                Image(systemName: method.icon).font(.system(size: 20)).frame(width: 28).accessibilityHidden(true)
                                Text(method.title).font(.system(size: 16, weight: .medium))
                                Spacer()
                                Image(systemName: payment == method ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 23))
                                    .accessibilityHidden(true)
                            }
                            .frame(minHeight: 64)
                            .contentShape(Rectangle())
                        }
                        .accessibilityLabel("\(method.title), booking preference")
                        .accessibilityAddTraits(payment == method ? .isSelected : [])
                        if method != DemoPayment.allCases.last { Divider().padding(.leading, 42) }
                    }
                }
            }
            .padding(20)
        }
        .background(.white)
        .foregroundStyle(.black)
        .buttonStyle(.plain)
        .navigationTitle("Wallet")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .tint(.black)
    }
}

struct SavedRidePlacesView: View {
    @EnvironmentObject private var store: RideStore
    @State private var add = false

    var body: some View {
        List {
            Section {
                if store.savedPlaces.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Keep your go-to places close").font(.system(size: 18, weight: .semibold))
                        Text("Save a destination so you can find it quickly next time you book.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 12)
                }
                ForEach(store.savedPlaces) { place in
                    if store.role == .rider {
                        Button { store.beginBooking(destination: place) } label: {
                            HStack {
                                RideLocationRow(place: place, icon: "bookmark.fill")
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .accessibilityHint("Choose this destination for a ride")
                    } else {
                        RideLocationRow(place: place, icon: "bookmark.fill")
                    }
                }
                .onDelete { store.savedPlaces.remove(atOffsets: $0) }
                Button { add = true } label: {
                    Label("Add a saved place", systemImage: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(minHeight: 44)
                }
            } footer: {
                Text("Saved places stay on this phone. Swipe a place to remove it.")
            }
        }
        .navigationTitle("Saved places")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton().disabled(store.savedPlaces.isEmpty)
            }
        }
        .sheet(isPresented: $add) {
            PlaceSearchView(title: "Save a place") { store.savePlace($0) }.environmentObject(store)
        }
        .tint(.black)
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
            Section {
                Toggle("Show requested pickup time", isOn: $store.rideReminders).tint(.black)
            } header: {
                Text("Trip display")
            } footer: {
                Text("Shows your recorded pickup time in the app. No push notifications are sent and drivers are not automatically dispatched.")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .tint(.black)
    }
}

struct RideHelpView: View {
    @EnvironmentObject private var store: RideStore

    var body: some View {
        List {
            Section("Your latest trip") {
                if let trip = store.state?.trips.max(by: { $0.createdAt < $1.createdAt }) {
                    NavigationLink { TripTrackingView(tripID: trip.id) } label: {
                        VStack(alignment: .leading, spacing: 7) {
                            Text(trip.destination.name).font(.headline)
                            Text(RideCatalog.date(trip.createdAt)).font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                    }
                } else if store.state == nil {
                    Text("Your latest trip will appear after your trips load.").font(.subheadline).foregroundStyle(.secondary)
                } else {
                    Text("No trips yet. Your latest ride will appear here.").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Section("Help topics") {
                NavigationLink("Trip progress and reservations") {
                    RideInfoView(title: "Trip progress", icon: "car.side", text: "Your driver accepts the request and updates the ride when they arrive, start, and finish. Apple map tiles show straight-line route previews, not driving directions or live tracking. Reservations record your requested pickup time but do not guarantee availability or automatically dispatch a driver.")
                }
                NavigationLink("Payments and trip totals") {
                    RideInfoView(title: "Payments and trip totals", icon: "creditcard", text: "Payments and payouts are unavailable. Trip details record fares, tip preferences, and a payment label, but no payment account is connected, authorized, or charged. Recorded trip totals are not receipts or proof of payment.")
                }
                NavigationLink("Connection problems") {
                    RideInfoView(title: "Connection problems", icon: "wifi.exclamationmark", text: "Check your internet connection and tap Retry if trip updates stop. If your session has expired, sign in again with your account.")
                }
                NavigationLink("Safety and assistance") {
                    RideInfoView(title: "Safety and assistance", icon: "shield.lefthalf.filled", text: "Emergency response, phone calls, audio recording, and safety monitoring are unavailable. If you need emergency assistance, call your local emergency number outside this app. Driver identity and vehicle details are not independently verified. Support requests and lost-item claims cannot be submitted in the app.")
                }
            }
        }
        .navigationTitle("Help")
        .navigationBarTitleDisplayMode(.inline)
        .tint(.black)
    }
}
