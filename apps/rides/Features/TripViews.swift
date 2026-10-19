import SwiftUI

struct TripTrackingView: View {
    @EnvironmentObject private var store: RideStore
    @Environment(\.dismiss) private var dismiss
    let tripID: String
    @State private var showCancel = false
    var body: some View {
        if let trip = store.state?.trips.first(where: { $0.id == tripID }) {
            if trip.status == .completed { RideReceiptView(tripID: tripID) }
            else {
                GeometryReader { geometry in
                    VStack(spacing: 0) {
                        ZStack(alignment: .bottomTrailing) {
                            DemoMapView(status: trip.status, pickup: trip.pickup, destination: trip.destination, stops: trip.stops)
                            NavigationLink { RideSafetyView(trip: trip) } label: { Image(systemName: "shield.lefthalf.filled").font(.system(size: 20)).foregroundStyle(.blue).frame(width: 46, height: 46).background(.white).clipShape(Circle()) }.padding(.trailing, 18).padding(.bottom, 32).accessibilityLabel("Safety information")
                        }.frame(height: geometry.size.height * 0.44)
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                Capsule().fill(.gray.opacity(0.15)).frame(width: 36, height: 4).frame(maxWidth: .infinity).accessibilityHidden(true)
                                Text(trip.status.title).font(.system(size: 21, weight: .semibold)).frame(maxWidth: .infinity)
                                if trip.status == .requested {
                                    HStack(spacing: 12) {
                                        ProgressView()
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text("Waiting for a driver to accept").font(.system(size: 15, weight: .semibold))
                                            Text("Your request is saved. You can leave this screen and return from Activity.").font(.system(size: 13)).foregroundStyle(.secondary)
                                        }
                                    }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(RideStyle.soft).clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                if trip.status == .cancelled {
                                    Text(trip.cancellationReason ?? "Plans changed.").font(.subheadline).foregroundStyle(.secondary)
                                    RidePrimaryButton(title: "Back to Home") { store.focusedTripID = nil; store.tab = 0; dismiss() }
                                }
                                if trip.status == .accepted || trip.status == .arriving || trip.status == .inProgress {
                                    VStack(alignment: .leading, spacing: 7) {
                                        Text(trip.status == .inProgress ? "Destination" : "Pickup spot").font(.system(size: 12)).foregroundStyle(.secondary)
                                        Text(trip.status == .inProgress ? trip.destination.name : trip.pickup.name).font(.system(size: 18, weight: .semibold))
                                        Text(trip.status == .inProgress ? trip.destination.address : trip.pickup.address).font(.system(size: 13)).foregroundStyle(.secondary)
                                        if trip.status != .inProgress {
                                            Text("Check the vehicle and plate before getting in.").font(.system(size: 12)).foregroundStyle(.secondary)
                                        }
                                    }.padding(16).frame(maxWidth: .infinity, alignment: .leading).overlay { RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.1)) }
                                }
                                if let driver = trip.driver {
                                    HStack(alignment: .center, spacing: 14) {
                                        ZStack { Circle().fill(RideStyle.soft); Image(systemName: "person.fill").font(.system(size: 30)).foregroundStyle(.gray) }.frame(width: 58, height: 58)
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(driver.name).font(.headline)
                                            if driver.rating > 0 { Label(String(format: "%.2f", driver.rating), systemImage: "star.fill").font(.caption) }
                                            else { Text("No ratings yet").font(.caption).foregroundStyle(.secondary) }
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 5) {
                                            Text(driver.plate).font(.system(size: 20, weight: .bold)).padding(.horizontal, 8).padding(.vertical, 5).background(RideStyle.soft).clipShape(RoundedRectangle(cornerRadius: 5))
                                            Text(driver.vehicle).font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                    if trip.canMessage {
                                        NavigationLink { RideChatView(tripID: trip.id) } label: { Label("Message driver", systemImage: "message.fill").font(.subheadline.bold()).frame(maxWidth: .infinity).padding(15).background(RideStyle.soft).clipShape(Capsule()) }.foregroundStyle(.black)
                                    }
                                }
                                Divider()
                                RideRouteSummary(pickup: trip.pickup, destination: trip.destination, stops: trip.stops)
                                HStack { Text(trip.serviceTitle); Spacer(); Text(RideCatalog.money(trip.status == .cancelled ? 0 : trip.fareCents)).fontWeight(.semibold) }.font(.subheadline)
                                if trip.status.isActive, store.rideReminders, let date = trip.scheduledAt { Label("Reservation: \(RideCatalog.date(date))", systemImage: "calendar").font(.caption) }
                                if !trip.note.isEmpty { Label(trip.note, systemImage: "text.bubble").font(.caption) }
                                if let error = store.errorMessage {
                                    Label(error, systemImage: "exclamationmark.circle.fill").font(.caption).foregroundStyle(.red)
                                }
                                if trip.status.canCancel { Button("Cancel ride", role: .destructive) { showCancel = true }.font(.subheadline.bold()).frame(maxWidth: .infinity).padding(.vertical, 10).disabled(store.busy) }
                            }.padding(20)
                        }.background(.white).clipShape(UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22)).padding(.top, -20)
                    }
                }.sheet(isPresented: $showCancel) { CancelRideView(trip: trip).environmentObject(store) }
            }
        } else { ContentUnavailableView("Ride not available", systemImage: "car.side", description: Text("Check your connection and try again.")) }
    }
}

struct DriverHomeView: View {
    @EnvironmentObject private var store: RideStore
    @State private var showCancel = false
    @State private var pendingAction: String?
    private var mapTrip: DemoTrip? {
        store.myDriverTrip ?? (store.isDriverOnline && store.activeTrip?.status == .requested ? store.activeTrip : nil)
    }
    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                DemoMapView(route: mapTrip != nil, status: mapTrip?.status ?? .requested, pickup: mapTrip?.pickup ?? RideCatalog.places[0], destination: mapTrip?.destination ?? RideCatalog.places[1], stops: mapTrip?.stops ?? [])
                VStack(spacing: 12) {
                    HStack {
                        Button { store.tab = 3 } label: { Image(systemName: "line.3.horizontal").font(.system(size: 20)).frame(width: 44, height: 44).background(.white).clipShape(Circle()) }.accessibilityLabel("Account")
                        Spacer()
                        Button { store.tab = 1 } label: { Text(RideCatalog.money(store.earningsCents)).font(.system(size: 22, weight: .bold)).padding(.horizontal, 22).padding(.vertical, 11).background(.black).foregroundStyle(.white).clipShape(Capsule()) }.accessibilityLabel("View recorded earnings, \(RideCatalog.money(store.earningsCents))")
                        Spacer()
                        Color.clear.frame(width: 44, height: 44)
                    }
                    Spacer()
                    if !store.isDriverOnline && store.myDriverTrip == nil {
                        Button {
                            Task { await store.setOnline(true) }
                        } label: {
                            Group {
                                if store.busy { ProgressView().tint(.white) }
                                else { Text("GO").font(.system(size: 27, weight: .bold)) }
                            }.frame(width: 84, height: 84).background(Color(red: 0.15, green: 0.42, blue: 0.96)).foregroundStyle(.white).clipShape(Circle()).overlay { Circle().stroke(.white, lineWidth: 5).padding(5) }.shadow(color: .black.opacity(0.18), radius: 8, y: 3)
                        }.padding(.bottom, 22).disabled(store.busy || store.state == nil).accessibilityLabel("Go online").accessibilityIdentifier("driver.goOnline")
                    }
                }.padding(18)
            }.frame(minHeight: 180, maxHeight: .infinity)
                .overlay(alignment: .bottomTrailing) {
                    if let trip = store.myDriverTrip {
                        NavigationLink { RideSafetyView(trip: trip) } label: {
                            Image(systemName: "shield.lefthalf.filled").font(.system(size: 20)).frame(width: 44, height: 44).background(.white).clipShape(Circle())
                        }.padding(.trailing, 18).padding(.bottom, 32).accessibilityLabel("Safety information")
                    }
                }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Capsule().fill(.gray.opacity(0.15)).frame(width: 36, height: 4).frame(maxWidth: .infinity).accessibilityHidden(true)
                    HStack(spacing: 7) {
                        Circle().fill(store.isDriverOnline ? RideStyle.green : .gray).frame(width: 7, height: 7)
                        Text(store.state == nil ? "Connecting…" : store.isDriverOnline ? "Online" : "Offline").font(.system(size: 13, weight: .semibold))
                        Spacer()
                        if store.isDriverOnline && store.myDriverTrip == nil {
                            Button("Go offline") { Task { await store.setOnline(false) } }.font(.system(size: 13, weight: .semibold)).disabled(store.busy).accessibilityIdentifier("driver.goOffline")
                        }
                    }
                    if let trip = store.myDriverTrip {
                        Text(trip.status == .accepted ? "Head to pickup" : trip.status == .arriving ? "Ready to start?" : "Drive to the destination").font(.system(size: 23, weight: .semibold))
                        Text(trip.status == .accepted ? "Let the rider know when you're at the pickup spot." : trip.status == .arriving ? "Confirm the rider is in the vehicle before starting." : "Complete the ride only after reaching the destination.").font(.system(size: 13)).foregroundStyle(.secondary)
                        HStack { Label(trip.riderName, systemImage: "person.fill").font(.headline); Spacer(); Text(trip.serviceTitle).font(.subheadline) }
                        RideRouteSummary(pickup: trip.pickup, destination: trip.destination, stops: trip.stops)
                        if !trip.note.isEmpty { Label(trip.note, systemImage: "text.bubble").font(.subheadline) }
                        if trip.canMessage {
                            NavigationLink { RideChatView(tripID: trip.id) } label: { Label("Message rider", systemImage: "message.fill").font(.subheadline.bold()).frame(maxWidth: .infinity).padding(14).background(RideStyle.soft).clipShape(Capsule()) }.foregroundStyle(.black)
                        }
                        RidePrimaryButton(title: trip.status == .accepted ? "I've arrived" : trip.status == .arriving ? "Start \(trip.serviceTitle)" : "Complete ride", busy: store.busy) {
                            if trip.status == .accepted { Task { await store.act(trip, RideAction(action: "arrive")) } }
                            else { pendingAction = trip.status == .arriving ? "start" : "complete" }
                        }.accessibilityIdentifier("driver.lifecycleAction")
                        if trip.status.canCancel { Button("Cancel ride", role: .destructive) { showCancel = true }.font(.subheadline.bold()).frame(maxWidth: .infinity).padding(.vertical, 10).disabled(store.busy) }
                    } else if let trip = store.activeTrip, trip.status == .requested, store.isDriverOnline {
                        HStack { Label("New ride request", systemImage: "person.fill").font(.headline); Spacer(); Text(trip.serviceTitle).font(.caption.bold()).padding(7).background(RideStyle.soft).clipShape(Capsule()) }
                        Text(RideCatalog.money(trip.fareCents)).font(.system(size: 36, weight: .bold))
                        Text("Recorded fare · No payment is processed").font(.caption).foregroundStyle(.secondary)
                        Text(trip.riderName).font(.headline)
                        RideRouteSummary(pickup: trip.pickup, destination: trip.destination, stops: trip.stops)
                        if let date = trip.scheduledAt { Label("Reserved: \(RideCatalog.date(date))", systemImage: "calendar").font(.caption) }
                        RidePrimaryButton(title: "Accept ride", busy: store.busy) { Task { await store.act(trip, RideAction(action: "accept")) } }
                            .accessibilityIdentifier("driver.acceptRide")
                        Text("Accepting assigns this ride to you. Review the pickup and destination first.").font(.caption).foregroundStyle(.secondary)
                    } else if store.state == nil {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Loading driver availability and ride requests…").font(.subheadline).foregroundStyle(.secondary)
                        }
                    } else {
                        Text(store.isDriverOnline ? "Finding ride requests" : "You're offline").font(.system(size: 24, weight: .semibold))
                        Text(store.isDriverOnline ? "New requests will appear here. Stay online to accept a ride when a rider requests one." : "Tap GO on the map to receive ride requests. You can go offline before accepting a ride.").font(.subheadline).foregroundStyle(.secondary)
                        Text("Austin, TX · Route preview, not live navigation").font(.caption).foregroundStyle(.secondary)
                    }
                    if let error = store.errorMessage {
                        Label(error, systemImage: "exclamationmark.circle.fill").font(.caption).foregroundStyle(.red).accessibilityIdentifier("driver.error")
                    }
                }.padding(20)
            }.frame(maxHeight: store.myDriverTrip != nil || (store.activeTrip?.status == .requested && store.isDriverOnline) ? 440 : 245)
                .background(.white).clipShape(UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22)).padding(.top, -20)
        }.background(.white)
            .sheet(isPresented: $showCancel) { if let trip = store.myDriverTrip { CancelRideView(trip: trip).environmentObject(store) } }
            .confirmationDialog(pendingAction == "start" ? "Is the rider in the vehicle?" : "Have you reached the destination?", isPresented: Binding(get: { pendingAction != nil }, set: { if !$0 { pendingAction = nil } }), titleVisibility: .visible) {
                if let trip = store.myDriverTrip, let action = pendingAction {
                    Button(action == "start" ? "Start ride" : "Complete ride") {
                        pendingAction = nil
                        Task { await store.act(trip, RideAction(action: action)) }
                    }
                }
                Button("Not yet", role: .cancel) { pendingAction = nil }
            } message: {
                Text(pendingAction == "start" ? "Starting updates the rider's trip status." : "This ends the ride for both participants. No payment will be processed.")
            }
    }
}

struct CancelRideView: View {
    @EnvironmentObject private var store: RideStore
    @Environment(\.dismiss) private var dismiss
    let trip: DemoTrip
    @State private var reason = "Changed my mind"
    private var reasons: [String] {
        store.role == .driver ? ["Rider didn't arrive", "Can't reach pickup", "Vehicle issue", "Other"] : ["Changed my mind", "Pickup location is wrong", "Driver is too far away", "Other"]
    }
    var body: some View {
        let currentTrip = store.state?.trips.first { $0.id == trip.id } ?? trip
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(trip.scheduledAt == nil ? "Cancel your ride?" : "Cancel your reservation?").font(.system(size: 27, weight: .bold))
                    Text("This ends the request for you and the other participant. Choose a reason below.").font(.subheadline).foregroundStyle(.secondary)
                    VStack(spacing: 0) {
                        ForEach(reasons, id: \.self) { option in
                            Button { reason = option } label: {
                                HStack {
                                    Text(option).font(.system(size: 16))
                                    Spacer()
                                    Image(systemName: reason == option ? "largecircle.fill.circle" : "circle").font(.system(size: 22))
                                }.padding(.vertical, 17).contentShape(Rectangle())
                            }.accessibilityAddTraits(reason == option ? .isSelected : [])
                            Divider()
                        }
                    }.disabled(store.busy)
                    if !currentTrip.status.canCancel {
                        Text("This ride can no longer be cancelled. Close this sheet to see its latest status.").font(.subheadline).foregroundStyle(.secondary)
                    }
                    if let error = store.errorMessage { Label(error, systemImage: "exclamationmark.circle.fill").font(.caption).foregroundStyle(.red) }
                    RidePrimaryButton(title: currentTrip.status.canCancel ? "Keep ride" : "Close", disabled: store.busy) { dismiss() }
                    Button(role: .destructive) {
                        Task { if await store.act(currentTrip, RideAction(action: "cancel", reason: reason)) { dismiss() } }
                    } label: {
                        HStack(spacing: 10) {
                            if store.busy { ProgressView() }
                            Text(store.busy ? "Cancelling ride…" : "Yes, cancel ride")
                        }.font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                    }.disabled(store.busy || !currentTrip.status.canCancel).accessibilityIdentifier("trip.confirmCancellation")
                }.padding(24)
            }.navigationTitle("Your ride").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.disabled(store.busy) } }
                .onAppear { if !reasons.contains(reason) { reason = reasons[0] } }
        }.tint(.black).presentationDetents([.large]).interactiveDismissDisabled(store.busy)
    }
}

struct RideChatView: View {
    @EnvironmentObject private var store: RideStore
    let tripID: String
    @State private var message = ""
    @FocusState private var messageFocused: Bool
    var body: some View {
        let trip = store.state?.trips.first { $0.id == tripID }
        VStack(spacing: 0) {
            Text("Keep your account safe. Never share sensitive personal, payment, or account information in chat.").font(.caption).foregroundStyle(.secondary).padding(14).frame(maxWidth: .infinity).background(RideStyle.soft)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 14) {
                        if trip?.messages.isEmpty == true {
                            VStack(spacing: 8) {
                                Image(systemName: "message").font(.system(size: 28)).foregroundStyle(.secondary)
                                Text(trip?.canMessage == true ? "Coordinate your pickup" : "No messages").font(.headline)
                                Text(trip?.canMessage == true ? "Send a quick reply or write a message below." : "Messages from this trip will appear here.").font(.subheadline).foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity).padding(.vertical, 24)
                        }
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
                }.scrollDismissesKeyboard(.interactively)
                    .onAppear { if let last = trip?.messages.last { proxy.scrollTo(last.id, anchor: .bottom) } }
                    .onChange(of: trip?.messages.count) { _, _ in if let last = trip?.messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } } }
            }
            if trip?.canMessage == true {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack { ForEach(["I'm here", "Be right there", "I'm looking for you"], id: \.self) { text in Button(text) { send(text, trip: trip) }.font(.caption.bold()).padding(12).background(RideStyle.soft).clipShape(Capsule()).disabled(store.busy) } }.padding(.horizontal, 18)
                }
                HStack {
                    TextField("Message", text: $message, axis: .vertical).lineLimit(1...4).focused($messageFocused).padding(13).background(RideStyle.soft).clipShape(Capsule()).accessibilityIdentifier("chat.message").accessibilityLabel("Message")
                    Button { send(message, trip: trip) } label: {
                        Group {
                            if store.busy { ProgressView().tint(.white) }
                            else { Image(systemName: "arrow.up").font(.headline) }
                        }.frame(width: 44, height: 44).background(.black).foregroundStyle(.white).clipShape(Circle())
                    }.disabled(store.busy || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || message.count > 500).accessibilityLabel("Send message")
                }.padding(18)
                if message.count > 500 { Text("Keep messages to 500 characters (\(message.count)/500).").font(.caption).foregroundStyle(.red).padding(.horizontal, 18) }
            } else { Text(trip?.status.isActive == true ? "Chat is available once a driver accepts the ride." : "This ride has ended. Chat is closed.").font(.subheadline).foregroundStyle(.secondary).padding(20) }
            if let error = store.errorMessage { Text(error).font(.caption).foregroundStyle(.red).padding(.horizontal, 18) }
        }.navigationTitle(store.role == .rider ? trip?.driver?.name ?? "Driver" : trip?.riderName ?? "Rider").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { messageFocused = false } } }.tint(.black)
    }
    private func send(_ text: String, trip: DemoTrip?) {
        guard let trip else { return }
        Task { if await store.act(trip, RideAction(action: "message", text: text)), message == text { message = "" } }
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
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        HStack {
                            Spacer()
                            Image(systemName: store.role == .rider ? "person.crop.circle.fill" : "checkmark.circle.fill")
                                .font(.system(size: 50)).foregroundStyle(store.role == .rider ? Color.gray.opacity(0.6) : RideStyle.green)
                            Spacer()
                        }.padding(.top, 12).accessibilityHidden(true).id("receipt.top")
                        Text(store.role == .rider ? "Thanks for riding" : "Ride completed").font(.system(size: 26, weight: .bold)).frame(maxWidth: .infinity)
                        Text("Recorded fare: \(RideCatalog.money(trip.fareCents))").font(.subheadline).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                        if store.role == .rider && (trip.rating == nil || editing) {
                            Text("Tip preference for \(trip.driver?.name ?? "your driver")").font(.system(size: 19, weight: .semibold)).multilineTextAlignment(.center).frame(maxWidth: .infinity)
                            Text("Payments unavailable. This preference does not send money.").font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: .infinity)
                            HStack(spacing: 10) {
                                ForEach([0, 100, 300, 500], id: \.self) { amount in
                                    Button(amount == 0 ? "No tip" : RideCatalog.money(amount)) { tip = amount }
                                        .font(.subheadline.bold()).frame(maxWidth: .infinity).padding(.vertical, 13)
                                        .background(tip == amount ? .black : .white).foregroundStyle(tip == amount ? .white : .black).clipShape(Capsule())
                                        .overlay { Capsule().stroke(Color.black.opacity(tip == amount ? 1 : 0.15), lineWidth: 1) }
                                        .disabled(store.busy).accessibilityAddTraits(tip == amount ? .isSelected : [])
                                        .accessibilityLabel(amount == 0 ? "No tip preference" : "\(RideCatalog.money(amount)) tip preference")
                                }
                            }
                            Divider().padding(.vertical, 4)
                            Text("Rate your trip").font(.system(size: 20, weight: .semibold)).frame(maxWidth: .infinity)
                            Text("\(trip.destination.name) · \(RideCatalog.date(trip.createdAt))").font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: .infinity)
                            HStack(spacing: 10) {
                                ForEach(1...5, id: \.self) { value in
                                    Button { rating = value } label: {
                                        Image(systemName: value <= rating ? "star.fill" : "star").font(.system(size: 32, weight: .light)).foregroundStyle(.black).frame(width: 44, height: 44)
                                    }.accessibilityLabel("\(value) star\(value == 1 ? "" : "s")").accessibilityAddTraits(rating == value ? .isSelected : []).disabled(store.busy)
                                        .accessibilityIdentifier("trip.rating.\(value)")
                                }
                            }.frame(maxWidth: .infinity)
                            if let error = store.errorMessage { Label(error, systemImage: "exclamationmark.circle.fill").font(.caption).foregroundStyle(.red) }
                            RidePrimaryButton(title: "Submit rating", busy: store.busy, disabled: rating == 0) {
                                Task { if await store.act(trip, RideAction(action: "rate", rating: rating, tipCents: tip)) { editing = false; store.focusedTripID = nil; store.tab = 2; dismiss() } }
                            }.accessibilityIdentifier("trip.submitRating")
                            Button(editing ? "Cancel editing" : "Skip for now") {
                                if editing { editing = false }
                                else { store.focusedTripID = nil; store.tab = 2; dismiss() }
                            }.font(.subheadline).frame(maxWidth: .infinity).padding(.vertical, 10).disabled(store.busy)
                        }
                        DemoMapView(status: trip.status, pickup: trip.pickup, destination: trip.destination, stops: trip.stops).frame(height: 150).clipShape(RoundedRectangle(cornerRadius: 12))
                        RideRouteSummary(pickup: trip.pickup, destination: trip.destination, stops: trip.stops)
                        Divider()
                        HStack { Text("Trip fare"); Spacer(); Text(RideCatalog.money(trip.fareCents)) }
                        HStack { Text("Tip preference"); Spacer(); Text(RideCatalog.money(trip.tipCents)) }
                        HStack { Text("Recorded total").font(.headline); Spacer(); Text(RideCatalog.money(trip.totalCents)).font(.title2.bold()) }
                        Label(DemoPayment.displayName(trip.paymentMethod), systemImage: "creditcard.fill").font(.subheadline)
                        if let rating = trip.rating {
                            Label("Your rating: \(rating) of 5", systemImage: "star.fill").font(.subheadline)
                            if store.role == .rider { Button("Edit rating and tip preference") { self.rating = rating; tip = trip.tipCents; editing = true }.disabled(store.busy) }
                        }
                        Text("\(RideCatalog.date(trip.createdAt)) · \(trip.serviceTitle)\nTrip \(trip.shortID)").font(.caption).foregroundStyle(.secondary)
                        Text("Payments unavailable. No payment was processed.").font(.caption).foregroundStyle(.secondary)
                        if let error = store.errorMessage, trip.rating != nil && !editing { Text(error).font(.caption).foregroundStyle(.red) }
                        if store.role == .rider {
                            RidePrimaryButton(title: store.activeTrip == nil ? "Ride again" : "View active ride", disabled: store.busy) {
                                dismiss()
                                if let active = store.activeTrip { store.focusedTripID = active.id; store.tab = 0; return }
                                store.focusedTripID = nil
                                store.beginBooking(destination: trip.destination)
                                store.draft.pickup = trip.pickup
                                store.draft.stops = trip.stops
                                store.draft.service = RideService(rawValue: trip.service) ?? .uberX
                            }.accessibilityIdentifier("trip.rideAgain")
                        }
                    }.padding(20)
                }.onChange(of: editing) { _, isEditing in
                    if isEditing { withAnimation { proxy.scrollTo("receipt.top", anchor: .top) } }
                }
            }.navigationTitle("Trip details").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar).tint(.black)
        } else { ContentUnavailableView("Receipt not available", systemImage: "receipt", description: Text("Check your connection and reopen this trip from Activity.")) }
    }
}

struct RideSafetyView: View {
    let trip: DemoTrip
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: "shield.lefthalf.filled").font(.system(size: 48)).foregroundStyle(.blue)
                Text("Safety toolkit").font(.system(size: 30, weight: .bold))
                Text("Emergency assistance unavailable").font(.headline)
                Text("For emergency assistance, call your local emergency number outside this app. Emergency calls, audio recording, crash monitoring, and location tracking are unavailable.").foregroundStyle(.secondary)
                ShareLink(item: "Ride \(trip.shortID)\n\(trip.pickup.name) → \(trip.destination.name)\nStatus: \(trip.status.title)\nTrip details only. Location sharing unavailable.") { Label("Share trip details", systemImage: "square.and.arrow.up").font(.headline).padding(18).frame(maxWidth: .infinity).background(RideStyle.soft).clipShape(RoundedRectangle(cornerRadius: 12)) }
                Text("Check the vehicle and plate before entering a car. Driver identity and vehicle details are not independently verified. PIN verification and safety monitoring are unavailable.").font(.subheadline).foregroundStyle(.secondary)
            }.padding(24)
        }.navigationTitle("Safety").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar).tint(.black)
    }
}
