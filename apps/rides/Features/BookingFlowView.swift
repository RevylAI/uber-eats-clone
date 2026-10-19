import SwiftUI

struct BookingFlowView: View {
    @EnvironmentObject private var store: RideStore
    @Environment(\.dismiss) private var dismiss
    @State private var step = 0
    @State private var query = ""
    @State private var placePicker: String?
    @State private var showSchedule = false
    @State private var showPayment = false
    @State private var schedule = Date().addingTimeInterval(3600)
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case destination, note }

    private var destinations: [DemoPlace] {
        RideCatalog.search(query, saved: store.savedPlaces).filter { place in
            place.id != store.draft.pickup.id && !store.draft.stops.contains { $0.id == place.id }
        }
    }

    private var excludedPlaceIDs: Set<String> {
        if placePicker == "pickup" { return Set(store.draft.stops.map(\.id) + [store.draft.destination?.id].compactMap { $0 }) }
        if placePicker == "destination" { return Set(store.draft.stops.map(\.id) + [store.draft.pickup.id]) }
        return Set(store.draft.stops.map(\.id) + [store.draft.pickup.id, store.draft.destination?.id].compactMap { $0 })
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    if step == 0 {
                        planView
                    } else {
                        ZStack(alignment: .topLeading) {
                            if focusedField != .note {
                                DemoMapView(pickup: store.draft.pickup, destination: store.draft.destination ?? store.draft.pickup, stops: store.draft.stops)
                            }
                            Button {
                                focusedField = nil
                                if step == 1 { query = store.draft.destination?.name ?? "" }
                                step -= 1
                            } label: {
                                Image(systemName: "arrow.left").font(.system(size: 20, weight: .medium))
                                    .frame(width: 44, height: 44).background(.white).clipShape(Circle())
                            }.padding(16).accessibilityLabel(step == 1 ? "Edit route" : "Back to ride options")
                        }.frame(height: focusedField == .note ? 76 : max(150, min(geometry.size.height * (step == 1 ? 0.27 : 0.34), 290)))
                        VStack(spacing: 0) {
                            Capsule().fill(Color.black.opacity(0.1)).frame(width: 36, height: 4).padding(.top, 9).padding(.bottom, 14).accessibilityHidden(true)
                            if step == 1 { chooseRideView }
                            else { confirmPickupView }
                        }
                        .background(.white)
                        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22))
                        .padding(.top, -20)
                    }
                    if focusedField != .note && (step > 0 || store.draft.destination != nil) { footer }
                }.background(.white)
            }
            .navigationTitle(step == 0 ? "Plan your ride" : "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(step == 0 ? .visible : .hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { focusedField = nil; dismiss() } label: { Image(systemName: "arrow.left") }
                        .accessibilityLabel("Close booking").disabled(store.busy)
                }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { focusedField = nil } }
            }
            .disabled(store.busy)
            .sheet(isPresented: $showSchedule) { scheduleView }
            .sheet(isPresented: $showPayment) {
                NavigationStack {
                    RideWalletView(payment: $store.draft.payment)
                        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { showPayment = false } } }
                }.tint(.black)
            }
            .sheet(isPresented: Binding(get: { placePicker != nil }, set: { if !$0 { placePicker = nil } })) {
                PlaceSearchView(title: placePicker == "pickup" ? "Pickup location" : placePicker == "destination" ? "Destination" : "Add a stop", excluding: excludedPlaceIDs) { place in
                    if placePicker == "pickup" { store.draft.pickup = place }
                    else if placePicker == "destination" { store.draft.destination = place; query = place.name }
                    else if store.draft.stops.count < 2 { store.draft.stops.append(place) }
                    placePicker = nil
                }
            }
            .onAppear {
                if let destination = store.draft.destination { query = destination.name; step = 1 }
                if let date = store.draft.scheduledAt { schedule = date }
            }
        }.tint(.black).interactiveDismissDisabled(store.busy)
    }

    private var planView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Label("For me", systemImage: "person.fill").font(.system(size: 14, weight: .medium))
                    Spacer()
                    Button { focusedField = nil; showSchedule = true } label: {
                        Label(store.draft.scheduledAt.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "Pickup now", systemImage: "clock.fill")
                            .font(.system(size: 13, weight: .medium)).padding(10).background(RideStyle.soft).clipShape(Capsule())
                    }.accessibilityLabel("Pickup time, \(store.draft.scheduledAt.map { $0.formatted() } ?? "now")")
                }
                VStack(spacing: 0) {
                    Button { focusedField = nil; placePicker = "pickup" } label: {
                        HStack {
                            RideLocationRow(place: store.draft.pickup, icon: "circle.inset.filled")
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                        }
                    }.accessibilityLabel("Edit pickup, \(store.draft.pickup.name)").accessibilityIdentifier("booking.pickup")
                    Divider().padding(.leading, 42)
                    HStack(spacing: 14) {
                        Image(systemName: "square.fill").font(.system(size: 13)).frame(width: 28)
                        TextField("Where to?", text: $query).font(.system(size: 17)).submitLabel(.search)
                            .focused($focusedField, equals: .destination).accessibilityIdentifier("booking.destination")
                            .accessibilityLabel("Destination")
                            .onChange(of: query) { _, value in
                                if value != store.draft.destination?.name { store.draft.destination = nil }
                            }
                        if !query.isEmpty {
                            Button { query = ""; focusedField = .destination } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.gray) }
                                .accessibilityLabel("Clear destination").frame(width: 32, height: 44)
                        }
                        if store.draft.stops.count < 2 {
                            Button { focusedField = nil; placePicker = "stop" } label: { Image(systemName: "plus").font(.system(size: 20)).frame(width: 32, height: 44) }
                                .accessibilityLabel("Add a stop")
                        }
                    }.padding(.vertical, 8)
                }.padding(.horizontal, 14).background(RideStyle.soft).clipShape(RoundedRectangle(cornerRadius: 12))
                if !store.draft.stops.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(store.draft.stops) { stop in
                            HStack {
                                RideLocationRow(place: stop, icon: "circle")
                                Button { store.draft.stops.removeAll { $0.id == stop.id } } label: {
                                    Image(systemName: "minus.circle.fill").frame(width: 44, height: 44)
                                }.accessibilityLabel("Remove stop, \(stop.name)")
                            }
                        }
                        Text("Up to 2 stops · $3.00 per stop added to your estimate").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                Text(query.isEmpty ? "Suggested destinations" : "Search results").font(.system(size: 16, weight: .semibold))
                VStack(spacing: 0) {
                    ForEach(destinations) { place in
                        Button {
                            query = place.name
                            store.draft.destination = place
                            focusedField = nil
                            step = 1
                        } label: {
                            RideLocationRow(place: place, icon: store.savedPlaces.contains(place) ? "star.fill" : "mappin.circle.fill")
                        }.accessibilityLabel("Destination, \(place.name), \(place.address)")
                        Divider().padding(.leading, 42)
                    }
                    if destinations.isEmpty {
                        ContentUnavailableView("No matching destinations", systemImage: "magnifyingglass", description: Text("Try Airport, Home, Work, or Coffee. Choose a location different from your pickup and stops."))
                    }
                }
                Text("Search available Austin locations. Live location search is unavailable.").font(.caption).foregroundStyle(.secondary)
            }.padding(20)
        }.scrollDismissesKeyboard(.interactively)
    }

    private var chooseRideView: some View {
        VStack(spacing: 0) {
            Text("Choose a ride").font(.system(size: 21, weight: .semibold)).padding(.bottom, 14)
            Divider()
            ScrollView {
                VStack(spacing: 8) {
                    Button { query = store.draft.destination?.name ?? ""; step = 0 } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "square.fill").font(.system(size: 10))
                            Text(store.draft.destination?.name ?? "Choose a destination").font(.system(size: 13, weight: .medium)).lineLimit(1)
                            Spacer()
                            Text("Edit").font(.system(size: 13, weight: .semibold))
                        }.padding(.horizontal, 4).padding(.vertical, 8)
                    }.accessibilityLabel("Edit route")
                    ForEach(RideService.allCases) { service in
                        Button { store.draft.service = service } label: {
                            HStack(spacing: 10) {
                                RideCarArt(service: service)
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack(spacing: 6) {
                                        Text(service.title).font(.system(size: 18, weight: .semibold))
                                        Label("\(service.seats)", systemImage: "person.fill").font(.system(size: 11))
                                    }
                                    Text(service.detail).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                                Text(RideCatalog.money(service.fareCents + store.draft.stops.count * 300)).font(.system(size: 16, weight: .semibold))
                            }.padding(.vertical, 15).padding(.horizontal, 10)
                                .background(store.draft.service == service ? RideStyle.soft.opacity(0.6) : .white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay { RoundedRectangle(cornerRadius: 14).stroke(store.draft.service == service ? Color.black : Color.clear, lineWidth: 2) }
                        }.foregroundStyle(.black).accessibilityIdentifier("booking.service.\(service.rawValue)")
                            .accessibilityAddTraits(store.draft.service == service ? .isSelected : [])
                    }
                    Text("Estimated fares · Driver availability and pickup times are not guaranteed.")
                        .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
                }.padding(18)
            }
        }
    }

    private var confirmPickupView: some View {
        GeometryReader { geometry in
            ScrollViewReader { scroll in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Confirm the pickup spot").font(.system(size: 22, weight: .semibold)).frame(maxWidth: .infinity)
                        Divider()
                        HStack {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Pickup").font(.caption).foregroundStyle(.secondary)
                                Text(store.draft.pickup.name).font(.system(size: 18, weight: .semibold))
                                Text(store.draft.pickup.address).font(.system(size: 13)).foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            Button { focusedField = nil; placePicker = "pickup" } label: {
                                Text("Edit").font(.system(size: 14, weight: .semibold)).padding(.horizontal, 18).padding(.vertical, 12).background(RideStyle.soft).clipShape(Capsule())
                            }.accessibilityLabel("Edit pickup location")
                        }
                        if let destination = store.draft.destination {
                            Button { focusedField = nil; placePicker = "destination" } label: {
                                HStack {
                                    Label(destination.name, systemImage: "square.fill").font(.subheadline).lineLimit(2)
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.caption)
                                }
                            }.accessibilityLabel("Edit destination, \(destination.name)")
                        }
                        if !store.draft.stops.isEmpty {
                            Button { focusedField = nil; query = store.draft.destination?.name ?? ""; step = 0 } label: {
                                Label("\(store.draft.stops.count) stop\(store.draft.stops.count == 1 ? "" : "s") · Edit route", systemImage: "point.topleft.down.to.point.bottomright.curvepath").font(.subheadline)
                            }
                        }
                        Button { focusedField = nil; showSchedule = true } label: {
                            Label(store.draft.scheduledAt.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "Pickup now", systemImage: "clock")
                                .font(.subheadline)
                        }.accessibilityLabel("Edit pickup time")
                        VStack(alignment: .leading, spacing: 6) {
                            TextField("Pickup note (optional)", text: $store.draft.note, axis: .vertical).lineLimit(2...3)
                                .focused($focusedField, equals: .note).padding(14).background(RideStyle.soft).clipShape(RoundedRectangle(cornerRadius: 10))
                                .accessibilityIdentifier("booking.pickupNote")
                            Text("\(store.draft.note.count)/300 characters").font(.caption).foregroundStyle(store.draft.note.count > 300 ? .red : .secondary).frame(maxWidth: .infinity, alignment: .trailing)
                        }.id(Field.note)
                        Text("Your request is sent when you confirm. You can cancel before the ride starts.").font(.caption).foregroundStyle(.secondary)
                    }.padding(.horizontal, 20).padding(.bottom, 18)
                }.scrollDismissesKeyboard(.interactively)
                    .onChange(of: focusedField) { _, _ in revealPickupNote(in: scroll) }
                    .onChange(of: geometry.size.height) { _, _ in revealPickupNote(in: scroll) }
                    .onChange(of: store.draft.note) { _, _ in revealPickupNote(in: scroll) }
            }
        }
    }

    private func revealPickupNote(in scroll: ScrollViewProxy) {
        guard focusedField == .note else { return }
        withAnimation { scroll.scrollTo(Field.note, anchor: .center) }
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Divider()
            if step > 0 {
                Button { focusedField = nil; showPayment = true } label: {
                    HStack {
                        Image(systemName: store.draft.payment.icon)
                        Text(store.draft.payment.title).font(.system(size: 14, weight: .medium))
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption)
                    }.foregroundStyle(.black).padding(.vertical, 4)
                }.accessibilityLabel("Payment preference, \(store.draft.payment.title)")
            }
            if let error = store.errorMessage ?? store.draft.validationError() {
                Label(error, systemImage: "exclamationmark.circle.fill").font(.caption).foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading).accessibilityIdentifier("booking.error")
            }
            RidePrimaryButton(title: store.busy ? "Requesting your ride…" : step == 0 ? "Continue" : step == 1 ? "Choose \(store.draft.service.title)" : store.connected ? "Confirm pickup · \(RideCatalog.money(store.draft.fareCents))" : "Sign in to request a ride", busy: store.busy, disabled: store.draft.validationError() != nil) {
                focusedField = nil
                if step < 2 { step += 1 }
                else if !store.connected { store.presentSignIn() }
                else { Task { await store.book() } }
            }.accessibilityIdentifier("booking.continue")
        }.padding(.horizontal, 20).padding(.bottom, 12).background(.white)
    }

    private var scheduleView: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("When do you want to be picked up?").font(.system(size: 26, weight: .bold))
                    DatePicker("Pickup time", selection: $schedule, in: Date().addingTimeInterval(60)...Date().addingTimeInterval(30 * 86400), displayedComponents: [.date, .hourAndMinute]).datePickerStyle(.graphical)
                    Text("Choose a pickup time up to 30 days ahead. A reservation does not guarantee driver availability.").font(.footnote).foregroundStyle(.secondary)
                    RidePrimaryButton(title: "Confirm pickup time", disabled: schedule <= Date() || schedule > Date().addingTimeInterval(30 * 86400)) {
                        store.draft.scheduledAt = schedule
                        showSchedule = false
                    }
                    Button("Ride now instead") { store.draft.scheduledAt = nil; showSchedule = false }.frame(maxWidth: .infinity).padding(.vertical, 10)
                }.padding(20)
            }.navigationTitle("Reserve a ride").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { showSchedule = false } } }
                .onAppear { schedule = max(store.draft.scheduledAt ?? schedule, Date().addingTimeInterval(120)) }
        }.tint(.black)
    }
}

struct PlaceSearchView: View {
    @EnvironmentObject private var store: RideStore
    @Environment(\.dismiss) private var dismiss
    var title: String
    var excluding: Set<String> = []
    var onSelect: (DemoPlace) -> Void
    @State private var query = ""

    var body: some View {
        let places = RideCatalog.search(query, saved: store.savedPlaces).filter { !excluding.contains($0.id) }
        NavigationStack {
            List {
                Section {
                    ForEach(places) { place in
                        Button { onSelect(place); dismiss() } label: { RideLocationRow(place: place) }
                    }
                } footer: {
                    Text(excluding.isEmpty ? "Search available Austin locations." : "Available Austin locations. Pickup, stops, and destination must be different.")
                }
            }.listStyle(.plain)
                .overlay {
                    if places.isEmpty {
                        ContentUnavailableView.search(text: query)
                    }
                }
                .searchable(text: $query, prompt: "Search locations")
                .scrollDismissesKeyboard(.interactively)
                .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }.tint(.black)
    }
}
