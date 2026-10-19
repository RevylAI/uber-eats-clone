import SwiftUI

struct TripTrackingView: View {
    @EnvironmentObject private var store: RideStore
    let tripID: String
    @State private var showCancel = false
    @State private var showCall = false
    var body: some View {
        if let trip = store.state?.trips.first(where: { $0.id == tripID }) {
            if trip.status == .completed { RideReceiptView(tripID: tripID) }
            else {
                GeometryReader { geometry in
                    VStack(spacing: 0) {
                        ZStack(alignment: .topTrailing) {
                            DemoMapView(status: trip.status)
                            NavigationLink { RideSafetyView(trip: trip) } label: { Image(systemName: "shield.lefthalf.filled").font(.system(size: 20)).foregroundStyle(.blue).frame(width: 46, height: 46).background(.white).clipShape(Circle()) }.padding(18)
                        }.frame(height: geometry.size.height * 0.43)
                        ScrollView {
                            VStack(alignment: .leading, spacing: 18) {
                                Capsule().fill(.gray.opacity(0.3)).frame(width: 38, height: 4).frame(maxWidth: .infinity)
                                HStack { Text(trip.status.title).font(.system(size: 24, weight: .bold)); Spacer() }
                                DemoConnectionBadge()
                                if trip.status == .requested {
                                    HStack(spacing: 12) { ProgressView(); Text(store.state?.driverOnline == true ? "Waiting for the driver phone to accept." : "Your demo driver is offline. Go online on the other phone to accept this ride.").font(.subheadline).foregroundStyle(.secondary) }
                                    Text("The request is shared with your demo room. It won't be accepted automatically.").font(.caption).foregroundStyle(.secondary)
                                }
                                if trip.status == .cancelled {
                                    Text(trip.cancellationReason ?? "Plans changed. No fee was charged.").font(.subheadline).foregroundStyle(.secondary)
                                    Text("No cancellation fee. No payment was collected.").font(.subheadline).foregroundStyle(.secondary)
                                    RidePrimaryButton(title: "Back to Home") { store.focusedTripID = nil }
                                }
                                if let driver = trip.driver {
                                    HStack(alignment: .center, spacing: 14) {
                                        ZStack { Circle().fill(RideStyle.soft); Image(systemName: "person.fill").font(.system(size: 30)).foregroundStyle(.gray) }.frame(width: 58, height: 58)
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(driver.name).font(.headline)
                                            Label(String(format: "%.2f", driver.rating), systemImage: "star.fill").font(.caption)
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 5) {
                                            Text(driver.plate).font(.system(size: 20, weight: .bold)).padding(.horizontal, 8).padding(.vertical, 5).background(RideStyle.soft).clipShape(RoundedRectangle(cornerRadius: 5))
                                            Text(driver.vehicle).font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                    if trip.canMessage {
                                        HStack(spacing: 12) {
                                            NavigationLink { RideChatView(tripID: trip.id) } label: { Label("Message driver", systemImage: "message.fill").font(.subheadline.bold()).frame(maxWidth: .infinity).padding(15).background(RideStyle.soft).clipShape(Capsule()) }
                                            Button { showCall = true } label: { Image(systemName: "phone.fill").frame(width: 48, height: 48).background(RideStyle.soft).clipShape(Circle()) }.accessibilityLabel("Demo call driver")
                                        }.foregroundStyle(.black)
                                    }
                                }
                                if trip.status.isActive {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text(trip.status == .inProgress ? "Enjoy the ride" : "Meet at your pickup spot").font(.headline)
                                        Text(trip.status == .inProgress ? trip.destination.name : trip.pickup.name).font(.subheadline)
                                        Text(trip.status == .inProgress ? "Your demo driver will complete the ride from the other phone." : "Your demo driver will mark arrival and start the trip from the other phone.").font(.caption).foregroundStyle(.secondary)
                                    }.padding(16).frame(maxWidth: .infinity, alignment: .leading).overlay { RoundedRectangle(cornerRadius: 12).stroke(.gray.opacity(0.22)) }
                                }
                                RideRouteSummary(pickup: trip.pickup, destination: trip.destination, stops: trip.stops)
                                HStack { Text(trip.serviceTitle); Spacer(); Text(RideCatalog.money(trip.status == .cancelled ? 0 : trip.fareCents)).fontWeight(.semibold) }.font(.subheadline)
                                if trip.status.isActive, store.rideReminders, let date = trip.scheduledAt { Label("Reservation: \(RideCatalog.date(date))", systemImage: "calendar").font(.caption) }
                                if !trip.note.isEmpty { Label(trip.note, systemImage: "text.bubble").font(.caption) }
                                if trip.status.canCancel { Button("Cancel ride", role: .destructive) { showCancel = true }.font(.subheadline.bold()).frame(maxWidth: .infinity).padding(.vertical, 10).disabled(store.busy) }
                                Text("Simulated map and travel times · No live GPS or real driver").font(.system(size: 10)).foregroundStyle(.secondary)
                            }.padding(20)
                        }
                    }
                }.sheet(isPresented: $showCancel) { CancelRideView(trip: trip).environmentObject(store) }
                    .alert("Demo call", isPresented: $showCall) { Button("OK", role: .cancel) {} } message: { Text("No phone call is placed. Use Message driver to send a real message between the two demo phones.") }
            }
        } else { ContentUnavailableView("Ride not available", systemImage: "car.side", description: Text("Reconnect to the demo server to refresh this ride.")) }
    }
}

struct DriverHomeView: View {
    @EnvironmentObject private var store: RideStore
    @State private var showCancel = false
    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                DemoMapView(route: store.myDriverTrip != nil, status: store.activeTrip?.status ?? .requested)
                VStack(spacing: 12) {
                    HStack {
                        Button { store.showConnection = true } label: { Image(systemName: "line.3.horizontal").font(.system(size: 20)).frame(width: 44, height: 44).background(.white).clipShape(Circle()) }
                        Spacer()
                        Button { store.tab = 1 } label: { Text(RideCatalog.money(store.earningsCents)).font(.system(size: 22, weight: .bold)).padding(.horizontal, 22).padding(.vertical, 11).background(.black).foregroundStyle(.white).clipShape(Capsule()) }
                        Spacer()
                        Image(systemName: "shield.lefthalf.filled").font(.system(size: 20)).frame(width: 44, height: 44).background(.white).clipShape(Circle()).accessibilityHidden(true)
                    }
                    DemoConnectionBadge().padding(8).background(.white.opacity(0.94)).clipShape(Capsule())
                    Spacer()
                    if !store.isDriverOnline && store.myDriverTrip == nil {
                        Button {
                            if store.connected { Task { await store.setOnline(true) } }
                            else { store.showConnection = true }
                        } label: {
                            Text("GO").font(.system(size: 27, weight: .bold)).frame(width: 84, height: 84).background(Color(red: 0.15, green: 0.42, blue: 0.96)).foregroundStyle(.white).clipShape(Circle()).overlay { Circle().stroke(.white, lineWidth: 5).padding(5) }.shadow(color: .black.opacity(0.18), radius: 8, y: 3)
                        }.padding(.bottom, 22).disabled(store.busy).accessibilityIdentifier("driver.goOnline")
                    }
                }.padding(18)
            }.frame(minHeight: 220, maxHeight: .infinity)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Capsule().fill(.gray.opacity(0.25)).frame(width: 38, height: 4).frame(maxWidth: .infinity)
                    if let trip = store.myDriverTrip {
                        Text(trip.status == .accepted ? "Head to pickup" : trip.status == .arriving ? "Ready to start?" : "Drive to the destination").font(.system(size: 25, weight: .bold))
                        HStack { Label(trip.riderName, systemImage: "person.fill").font(.headline); Spacer(); Text(trip.serviceTitle).font(.subheadline) }
                        RideRouteSummary(pickup: trip.pickup, destination: trip.destination, stops: trip.stops)
                        if !trip.note.isEmpty { Label(trip.note, systemImage: "text.bubble").font(.subheadline) }
                        NavigationLink { RideChatView(tripID: trip.id) } label: { Label("Message rider", systemImage: "message.fill").font(.subheadline.bold()).frame(maxWidth: .infinity).padding(14).background(RideStyle.soft).clipShape(Capsule()) }.foregroundStyle(.black)
                        RidePrimaryButton(title: trip.status == .accepted ? "I've arrived" : trip.status == .arriving ? "Start \(trip.serviceTitle)" : "Complete ride", busy: store.busy) {
                            Task { await store.act(trip, RideAction(action: trip.status == .accepted ? "arrive" : trip.status == .arriving ? "start" : "complete")) }
                        }
                        if trip.status.canCancel { Button("Cancel ride", role: .destructive) { showCancel = true }.font(.caption.bold()).frame(maxWidth: .infinity) }
                    } else if let trip = store.activeTrip, trip.status == .requested, store.isDriverOnline {
                        HStack { Label("New ride request", systemImage: "person.fill").font(.headline); Spacer(); Text(trip.serviceTitle).font(.caption.bold()).padding(7).background(RideStyle.soft).clipShape(Capsule()) }
                        Text(RideCatalog.money(trip.fareCents)).font(.system(size: 42, weight: .bold))
                        Text(trip.riderName).font(.headline)
                        RideRouteSummary(pickup: trip.pickup, destination: trip.destination, stops: trip.stops)
                        if let date = trip.scheduledAt { Label("Reserved: \(RideCatalog.date(date))", systemImage: "calendar").font(.caption) }
                        RidePrimaryButton(title: "Accept ride", busy: store.busy) { Task { await store.act(trip, RideAction(action: "accept")) } }
                            .accessibilityIdentifier("driver.acceptRide")
                        Text("Accepting here updates the rider phone. No real trip is dispatched.").font(.caption).foregroundStyle(.secondary)
                    } else {
                        HStack {
                            Text(store.isDriverOnline ? "You're online" : "You're offline").font(.system(size: 26, weight: .bold))
                            Spacer()
                            if store.isDriverOnline { Button("Go offline") { Task { await store.setOnline(false) } }.font(.subheadline.bold()).disabled(store.busy) }
                        }
                        Text(store.isDriverOnline ? store.activeTrip == nil ? "Waiting for a request from the rider phone." : "Another driver accepted this ride." : "Go online to receive ride requests from your demo room.").font(.subheadline).foregroundStyle(.secondary)
                        if !store.connected { RidePrimaryButton(title: "Join a rider's demo room") { store.showConnection = true } }
                        HStack { Image(systemName: "checkmark.shield.fill").foregroundStyle(RideStyle.green); Text("Driver companion demo").font(.caption.bold()); Spacer(); Text("Austin, TX").font(.caption).foregroundStyle(.secondary) }.padding(.top, 8)
                    }
                }.padding(20)
            }.frame(maxHeight: store.myDriverTrip != nil || (store.activeTrip?.status == .requested && store.isDriverOnline) ? 430 : 200)
        }.background(.white).sheet(isPresented: $showCancel) { if let trip = store.myDriverTrip { CancelRideView(trip: trip).environmentObject(store) } }
    }
}

struct CancelRideView: View {
    @EnvironmentObject private var store: RideStore
    @Environment(\.dismiss) private var dismiss
    let trip: DemoTrip
    @State private var reason = "Changed my mind"
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 22) {
                Text(trip.scheduledAt == nil ? "Cancel your ride?" : "Cancel your reservation?").font(.system(size: 29, weight: .bold))
                Text("You won't be charged a cancellation fee. The other phone will see the ride cancelled.").foregroundStyle(.secondary)
                Picker("Reason", selection: $reason) {
                    ForEach(["Changed my mind", "Pickup location is wrong", "Driver is too far away", "Other"], id: \.self) { Text($0).tag($0) }
                }.pickerStyle(.inline)
                if let error = store.errorMessage { Text(error).font(.caption).foregroundStyle(.red) }
                RidePrimaryButton(title: "Keep ride") { dismiss() }
                Button("Cancel ride", role: .destructive) {
                    Task { if await store.act(trip, RideAction(action: "cancel", reason: reason)) { dismiss() } }
                }.font(.headline).frame(maxWidth: .infinity).padding(10).disabled(store.busy)
                Spacer()
            }.padding(24).navigationTitle("Your ride").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }.tint(.black).presentationDetents([.large])
    }
}

struct RideChatView: View {
    @EnvironmentObject private var store: RideStore
    let tripID: String
    @State private var message = ""
    var body: some View {
        let trip = store.state?.trips.first { $0.id == tripID }
        VStack(spacing: 0) {
            Text("Keep your account safe. Never share personal, payment, or account information in this demo chat.").font(.caption).foregroundStyle(.secondary).padding(14).frame(maxWidth: .infinity).background(RideStyle.soft)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(trip?.messages ?? []) { message in
                            HStack {
                                if message.senderId == store.credentials?.participantId { Spacer(minLength: 35) }
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(message.senderName).font(.caption.bold())
                                    Text(message.text).font(.body)
                                }.padding(14).background(message.senderId == store.credentials?.participantId ? Color.black : RideStyle.soft).foregroundStyle(message.senderId == store.credentials?.participantId ? .white : .black).clipShape(RoundedRectangle(cornerRadius: 16))
                                if message.senderId != store.credentials?.participantId { Spacer(minLength: 35) }
                            }.id(message.id)
                        }
                    }.padding(20)
                }.onChange(of: trip?.messages.count) { _, _ in if let last = trip?.messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } } }
            }
            if trip?.canMessage == true {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack { ForEach(["I'm here", "Be right there", "I'm looking for you"], id: \.self) { text in Button(text) { send(text, trip: trip) }.font(.caption.bold()).padding(12).background(RideStyle.soft).clipShape(Capsule()).disabled(store.busy) } }.padding(.horizontal, 18)
                }
                HStack {
                    TextField("Message", text: $message, axis: .vertical).lineLimit(1...4).padding(13).background(RideStyle.soft).clipShape(Capsule()).accessibilityIdentifier("chat.message")
                    Button { send(message, trip: trip) } label: { Image(systemName: "arrow.up").font(.headline).frame(width: 44, height: 44).background(.black).foregroundStyle(.white).clipShape(Circle()) }.disabled(store.busy || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || message.count > 500).accessibilityLabel("Send message")
                }.padding(18)
            } else { Text("This ride has ended. Chat is closed.").font(.subheadline).foregroundStyle(.secondary).padding(20) }
            if let error = store.errorMessage { Text(error).font(.caption).foregroundStyle(.red).padding(.horizontal, 18) }
        }.navigationTitle(store.role == .rider ? trip?.driver?.name ?? "Driver" : trip?.riderName ?? "Rider").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar).tint(.black)
    }
    private func send(_ text: String, trip: DemoTrip?) {
        guard let trip else { return }
        Task { if await store.act(trip, RideAction(action: "message", text: text)) { message = "" } }
    }
}

struct RideReceiptView: View {
    @EnvironmentObject private var store: RideStore
    @Environment(\.dismiss) private var dismiss
    let tripID: String
    @State private var rating = 0
    @State private var tip = 0
    @State private var editing = false
    var body: some View {
        if let trip = store.state?.trips.first(where: { $0.id == tripID }) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack { Spacer(); Image(systemName: "checkmark.circle.fill").font(.system(size: 52)).foregroundStyle(RideStyle.green); Spacer() }.padding(.top, 22)
                    Text("Thanks for riding").font(.system(size: 30, weight: .bold)).frame(maxWidth: .infinity)
                    Text("Your trip was \(RideCatalog.money(trip.fareCents))").font(.subheadline).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                    if store.role == .rider && (trip.rating == nil || editing) {
                        Text("Add a tip for \(trip.driver?.name ?? "your driver")").font(.headline).frame(maxWidth: .infinity)
                        HStack(spacing: 10) {
                            ForEach([0, 100, 300, 500], id: \.self) { amount in
                                Button(amount == 0 ? "No tip" : RideCatalog.money(amount)) { tip = amount }.font(.subheadline.bold()).frame(maxWidth: .infinity).padding(.vertical, 12).background(tip == amount ? .black : RideStyle.soft).foregroundStyle(tip == amount ? .white : .black).clipShape(Capsule())
                            }
                        }
                        Text("Rate your trip").font(.headline).frame(maxWidth: .infinity)
                        HStack(spacing: 18) {
                            ForEach(1...5, id: \.self) { value in
                                Button { rating = value } label: { Image(systemName: value <= rating ? "star.fill" : "star").font(.system(size: 33)).foregroundStyle(.black) }.accessibilityLabel("\(value) star\(value == 1 ? "" : "s")")
                            }
                        }.frame(maxWidth: .infinity)
                        RidePrimaryButton(title: "Submit rating", busy: store.busy, disabled: rating == 0) {
                            Task { if await store.act(trip, RideAction(action: "rate", rating: rating, tipCents: tip)) { editing = false; store.focusedTripID = nil; store.tab = 2; dismiss() } }
                        }
                        Button("Skip for now") { store.focusedTripID = nil; store.tab = 2; dismiss() }.font(.subheadline).frame(maxWidth: .infinity)
                    }
                    DemoMapView().frame(height: 130).clipShape(RoundedRectangle(cornerRadius: 12))
                    RideRouteSummary(pickup: trip.pickup, destination: trip.destination, stops: trip.stops)
                    Divider()
                    HStack { Text("Trip fare"); Spacer(); Text(RideCatalog.money(trip.fareCents)) }
                    HStack { Text("Tip"); Spacer(); Text(RideCatalog.money(trip.tipCents)) }
                    HStack { Text("Total").font(.headline); Spacer(); Text(RideCatalog.money(trip.totalCents)).font(.title2.bold()) }
                    Label(trip.paymentMethod, systemImage: "creditcard.fill").font(.subheadline)
                    if let rating = trip.rating {
                        Label("Your rating: \(rating) of 5", systemImage: "star.fill").font(.subheadline)
                        if store.role == .rider { Button("Edit rating and tip") { self.rating = rating; tip = trip.tipCents; editing = true } }
                    }
                    Text("\(RideCatalog.date(trip.createdAt)) · \(trip.serviceTitle)\nTrip \(trip.shortID)").font(.caption).foregroundStyle(.secondary)
                    Text("Demo receipt. No money was transferred.").font(.caption).foregroundStyle(.secondary)
                    if let error = store.errorMessage { Text(error).font(.caption).foregroundStyle(.red) }
                    if store.role == .rider && trip.rating != nil {
                        RidePrimaryButton(title: "Ride again") { store.beginBooking(destination: trip.destination); store.draft.pickup = trip.pickup; store.draft.stops = trip.stops; store.draft.service = RideService(rawValue: trip.service) ?? .uberX }
                    }
                }.padding(20)
            }.navigationTitle("Trip details").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar).tint(.black)
        }
    }
}

struct RideSafetyView: View {
    let trip: DemoTrip
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: "shield.lefthalf.filled").font(.system(size: 48)).foregroundStyle(.blue)
                Text("Safety toolkit").font(.system(size: 30, weight: .bold))
                Text("This is a demo, not an emergency service.").font(.headline)
                Text("If you need real emergency assistance, contact your local emergency number outside this app. The demo does not call emergency services, record audio, monitor crashes, or track your location.").foregroundStyle(.secondary)
                ShareLink(item: "Demo ride \(trip.shortID)\n\(trip.pickup.name) → \(trip.destination.name)\nStatus: \(trip.status.title)\nThis is a simulated ride, not live location sharing.") { Label("Share demo trip details", systemImage: "square.and.arrow.up").font(.headline).padding(18).frame(maxWidth: .infinity).background(RideStyle.soft).clipShape(RoundedRectangle(cornerRadius: 12)) }
                Text("Before a real ride, verify the driver's photo, vehicle, and plate. No PIN verification or safety monitoring is implemented in this demo.").font(.subheadline).foregroundStyle(.secondary)
            }.padding(24)
        }.navigationTitle("Safety").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar).tint(.black)
    }
}
