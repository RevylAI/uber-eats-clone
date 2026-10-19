import SwiftUI

struct BookingFlowView: View {
    @EnvironmentObject private var store: RideStore
    @Environment(\.dismiss) private var dismiss
    @State private var step = 0
    @State private var query = ""
    @State private var placePicker: String?
    @State private var showSchedule = false
    @State private var showPayment = false
    @State private var showConnect = false
    @State private var schedule = Date().addingTimeInterval(3600)
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if step == 0 { planView }
                else {
                    ZStack(alignment: .topLeading) {
                        DemoMapView().frame(height: step == 1 ? 210 : 280)
                        Button { step -= 1 } label: { Image(systemName: "arrow.left").font(.system(size: 20, weight: .medium)).frame(width: 43, height: 43).background(.white).clipShape(Circle()) }.padding(16)
                    }
                    if step == 1 { chooseRideView }
                    else { confirmPickupView }
                }
                if step > 0 { footer }
            }
            .background(.white)
            .navigationTitle(step == 0 ? "Plan your ride" : "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(step == 0 ? .visible : .hidden, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button { dismiss() } label: { Image(systemName: "arrow.left") }.accessibilityLabel("Close booking") } }
            .sheet(isPresented: $showSchedule) {
                NavigationStack {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("When do you want to be picked up?").font(.system(size: 28, weight: .bold))
                        DatePicker("Pickup time", selection: $schedule, in: Date().addingTimeInterval(60)...Date().addingTimeInterval(30 * 86400), displayedComponents: [.date, .hourAndMinute]).datePickerStyle(.graphical)
                        Text("Reserve up to 30 days ahead. In this demo, the driver manually advances reservations immediately; there is no timed dispatch.").font(.footnote).foregroundStyle(.secondary)
                        RidePrimaryButton(title: "Confirm pickup time") { store.draft.scheduledAt = schedule; showSchedule = false }
                        Button("Ride now instead") { store.draft.scheduledAt = nil; showSchedule = false }.frame(maxWidth: .infinity)
                        Spacer()
                    }.padding(20).navigationTitle("Reserve a ride").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { showSchedule = false } } }
                }.tint(.black)
            }
            .sheet(isPresented: $showPayment) { NavigationStack { RideWalletView(payment: $store.draft.payment).toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { showPayment = false } } } }.tint(.black) }
            .sheet(isPresented: $showConnect) { DemoConnectionView().environmentObject(store) }
            .sheet(isPresented: Binding(get: { placePicker != nil }, set: { if !$0 { placePicker = nil } })) {
                PlaceSearchView(title: placePicker == "pickup" ? "Pickup location" : "Add a stop") { place in
                    if placePicker == "pickup" { store.draft.pickup = place }
                    else if store.draft.stops.count < 2 { store.draft.stops.append(place) }
                    placePicker = nil
                }
            }
            .onAppear {
                if store.draft.destination != nil { step = 1 }
                if let date = store.draft.scheduledAt { schedule = date }
            }
        }.tint(.black).interactiveDismissDisabled(store.busy)
    }

    private var planView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Label("For me", systemImage: "person.fill").font(.system(size: 13, weight: .medium))
                    Spacer()
                    Button { showSchedule = true } label: { Label(store.draft.scheduledAt.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "Pickup now", systemImage: "clock.fill").font(.system(size: 13, weight: .medium)).padding(10).background(RideStyle.soft).clipShape(Capsule()) }
                }
                VStack(spacing: 0) {
                    Button { placePicker = "pickup" } label: { RideLocationRow(place: store.draft.pickup, icon: "circle.inset.filled") }
                    Divider()
                    HStack(spacing: 14) {
                        Image(systemName: "square.fill").frame(width: 28)
                        TextField("Where to?", text: $query).font(.system(size: 17)).submitLabel(.search).accessibilityIdentifier("booking.destination")
                        if store.draft.stops.count < 2 { Button { placePicker = "stop" } label: { Image(systemName: "plus").font(.system(size: 20)) }.accessibilityLabel("Add a stop") }
                    }.padding(.vertical, 18)
                }.padding(.horizontal, 14).background(RideStyle.soft).clipShape(RoundedRectangle(cornerRadius: 10))
                ForEach(store.draft.stops) { stop in
                    HStack { RideLocationRow(place: stop, icon: "circle"); Button { store.draft.stops.removeAll { $0.id == stop.id } } label: { Image(systemName: "minus.circle.fill") }.accessibilityLabel("Remove \(stop.name)") }
                }
                if !store.draft.stops.isEmpty { Text("Each demo stop adds $3.00 to the fare.").font(.caption).foregroundStyle(.secondary) }
                Text("Suggested destinations").font(.subheadline.bold())
                ForEach(RideCatalog.search(query, saved: store.savedPlaces).filter { $0.id != store.draft.pickup.id && !store.draft.stops.contains($0) }) { place in
                    Button { store.draft.destination = place; step = 1 } label: { RideLocationRow(place: place, icon: store.savedPlaces.contains(place) ? "star.fill" : "mappin.circle.fill") }
                    Divider().padding(.leading, 42)
                }
                if RideCatalog.search(query, saved: store.savedPlaces).isEmpty { Text("No demo locations found. Try Airport, Home, Work, or Coffee.").font(.subheadline).foregroundStyle(.secondary).padding(.vertical, 20) }
                Text("Locations and routes use an offline Austin demo catalog. No live geocoding.").font(.caption).foregroundStyle(.secondary)
            }.padding(20)
        }.scrollDismissesKeyboard(.interactively)
    }

    private var chooseRideView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Choose a ride").font(.system(size: 22, weight: .bold)).frame(maxWidth: .infinity).padding(.bottom, 6)
                ForEach(RideService.allCases) { service in
                    Button { store.draft.service = service } label: {
                        HStack(spacing: 9) {
                            RideCarArt(service: service)
                            VStack(alignment: .leading, spacing: 5) {
                                HStack(spacing: 6) { Text(service.title).font(.system(size: 17, weight: .semibold)); Label("\(service.seats)", systemImage: "person.fill").font(.system(size: 10)) }
                                Text(store.draft.scheduledAt == nil ? "4 min away · Demo estimate" : "Scheduled demo pickup").font(.system(size: 11)).foregroundStyle(.secondary)
                                Text(service.detail).font(.system(size: 11)).foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            Text(RideCatalog.money(service.fareCents + store.draft.stops.count * 300)).font(.system(size: 15, weight: .semibold))
                        }.padding(.vertical, 12).padding(.horizontal, 8).background(.white).clipShape(RoundedRectangle(cornerRadius: 12)).overlay { RoundedRectangle(cornerRadius: 12).stroke(store.draft.service == service ? Color.black : Color.clear, lineWidth: 2) }
                    }.foregroundStyle(.black).accessibilityIdentifier("booking.service.\(service.rawValue)")
                }
            }.padding(18)
        }
    }

    private var confirmPickupView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Confirm your pickup").font(.system(size: 25, weight: .bold))
                Text("Meet your driver at the pickup spot. This is a simulated trip, not a real booking.").font(.subheadline).foregroundStyle(.secondary)
                if let destination = store.draft.destination {
                    RideRouteSummary(pickup: store.draft.pickup, destination: destination, stops: store.draft.stops)
                }
                if let date = store.draft.scheduledAt {
                    Label(date.formatted(date: .complete, time: .shortened), systemImage: "calendar").font(.subheadline.bold())
                    Text("Reservations appear on the driver phone immediately and are manually advanced in this demo.").font(.caption).foregroundStyle(.secondary)
                }
                TextField("Add a pickup note (optional)", text: $store.draft.note, axis: .vertical).lineLimit(2...4).padding(14).background(RideStyle.soft).clipShape(RoundedRectangle(cornerRadius: 10))
                Text("You can cancel before the ride starts. No cancellation fees or real charges apply.").font(.caption).foregroundStyle(.secondary)
            }.padding(20)
        }.scrollDismissesKeyboard(.interactively)
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Divider()
            Button { showPayment = true } label: {
                HStack { Image(systemName: store.draft.payment.icon); Text(store.draft.payment.rawValue).font(.system(size: 14, weight: .medium)); Spacer(); Image(systemName: "chevron.right").font(.caption) }.foregroundStyle(.black)
            }
            if let error = store.errorMessage { Text(error).font(.caption).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .leading) }
            RidePrimaryButton(title: step == 1 ? "Choose \(store.draft.service.title)" : store.connected ? "Confirm pickup · \(RideCatalog.money(store.draft.fareCents))" : "Connect to request a ride", busy: store.busy, disabled: store.draft.validationError() != nil) {
                if step == 1 { step = 2 }
                else if !store.connected { showConnect = true }
                else { Task { await store.book() } }
            }
            Text("Demo fare · No payment will be collected").font(.system(size: 10)).foregroundStyle(.secondary)
        }.padding(.horizontal, 20).padding(.bottom, 12).background(.white)
    }
}

struct PlaceSearchView: View {
    @EnvironmentObject private var store: RideStore
    @Environment(\.dismiss) private var dismiss
    var title: String
    var onSelect: (DemoPlace) -> Void
    @State private var query = ""
    var body: some View {
        NavigationStack {
            List(RideCatalog.search(query, saved: store.savedPlaces)) { place in
                Button { onSelect(place); dismiss() } label: { RideLocationRow(place: place) }
            }.listStyle(.plain).searchable(text: $query, prompt: "Search demo locations").navigationTitle(title).navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }.tint(.black)
    }
}
