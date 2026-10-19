import SwiftUI

struct RiderHomeView: View {
    @EnvironmentObject private var store: RideStore
    @State private var eatsInfo = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Go anywhere")
                    .font(.system(size: 32, weight: .bold))
                    .tracking(-0.8)
                    .padding(.top, 12)

                HStack(spacing: 24) {
                    VStack(spacing: 10) {
                        Label("Rides", systemImage: "car.side.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Rectangle().frame(height: 3)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Rides, selected")
                    Button {
                        if let url = URL(string: "eatsclone://home"), UIApplication.shared.canOpenURL(url) {
                            UIApplication.shared.open(url)
                        } else {
                            eatsInfo = true
                        }
                    } label: {
                        VStack(spacing: 10) {
                            Label("Eats", systemImage: "takeoutbag.and.cup.and.straw.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Color.clear.frame(height: 3)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Open Eats")
                }

                HStack(spacing: 8) {
                    Button { store.beginBooking() } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass").font(.system(size: 20, weight: .semibold))
                            Text("Where to?").font(.system(size: 22, weight: .semibold))
                            Spacer(minLength: 0)
                        }
                        .frame(minHeight: 48)
                        .contentShape(Rectangle())
                    }
                    .accessibilityIdentifier("rider.whereTo")
                    Button { store.beginBooking(reserve: true) } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                            Text("Later").fontWeight(.semibold)
                            Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
                        }
                        .font(.system(size: 13))
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .background(.white)
                        .clipShape(Capsule())
                    }
                    .accessibilityLabel("Choose a preferred pickup time")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(RideStyle.soft)
                .clipShape(RoundedRectangle(cornerRadius: 30))

                VStack(alignment: .leading, spacing: 4) {
                    Text(store.savedPlaces.isEmpty ? "Places to go" : "Your saved places")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    let places = store.savedPlaces.isEmpty ? Array(RideCatalog.places.dropFirst().prefix(2)) : Array(store.savedPlaces.prefix(2))
                    ForEach(places) { place in
                        Button { store.beginBooking(destination: place) } label: {
                            HStack(spacing: 8) {
                                RideLocationRow(place: place, icon: store.savedPlaces.isEmpty ? "mappin" : "star.fill")
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .accessibilityHint("Choose this destination for a ride")
                        if place.id != places.last?.id { Divider().padding(.leading, 42) }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Suggestions").font(.system(size: 22, weight: .bold))
                        Spacer()
                        Button("See all") { store.tab = 1 }
                            .font(.system(size: 14, weight: .semibold))
                            .frame(minWidth: 44, minHeight: 44)
                            .accessibilityLabel("See all ride services")
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 10)], spacing: 12) {
                        Button { store.beginBooking() } label: { shortcut("Ride", service: .uberX) }
                        Button { store.beginBooking(reserve: true) } label: { shortcut("Reserve", icon: "calendar") }
                        Button { store.beginBooking(); store.draft.service = .comfort } label: { shortcut("Comfort", service: .comfort) }
                        NavigationLink { SavedRidePlacesView() } label: { shortcut("Saved", icon: "bookmark.fill") }
                    }
                }

                Button { store.beginBooking(reserve: true) } label: {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top, spacing: 16) {
                            VStack(alignment: .leading, spacing: 7) {
                                Text("Plan your next ride").font(.system(size: 23, weight: .bold))
                                Text("Record your preferred pickup time ahead of your trip.")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "calendar")
                                .font(.system(size: 28, weight: .medium))
                                .padding(12)
                                .background(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .accessibilityHidden(true)
                        }
                        Label("Explore Reserve", systemImage: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                        Text("No automatic timed dispatch or guaranteed driver availability.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .multilineTextAlignment(.leading)
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RideStyle.soft)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(.white)
        .foregroundStyle(.black)
        .buttonStyle(.plain)
        .alert("Eats isn't installed", isPresented: $eatsInfo) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Install Eats to open it from here.")
        }
    }

    private func shortcut(_ title: String, service: RideService? = nil, icon: String = "") -> some View {
        VStack(spacing: 8) {
            Group {
                if let service {
                    RideCarArt(service: service).scaleEffect(0.7)
                } else {
                    Image(systemName: icon).font(.system(size: 26, weight: .medium)).accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(RideStyle.soft)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            Text(title).font(.system(size: 12, weight: .semibold))
        }
        .accessibilityElement(children: .combine)
    }
}

struct RideServicesView: View {
    @EnvironmentObject private var store: RideStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(store.role == .driver ? "Earnings" : "Services")
                    .font(.system(size: 32, weight: .bold))
                    .tracking(-0.8)
                    .padding(.top, 12)
                if store.role == .driver {
                    driverTotals
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Go anywhere").font(.system(size: 18, weight: .bold))
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(RideService.allCases) { service in
                                Button { store.beginBooking(); store.draft.service = service } label: {
                                    VStack(alignment: .leading, spacing: 9) {
                                        RideCarArt(service: service)
                                            .frame(maxWidth: .infinity, alignment: .trailing)
                                            .padding(.bottom, 3)
                                        Text(service.title).font(.system(size: 16, weight: .semibold))
                                        Text(service.detail)
                                            .font(.system(size: 12))
                                            .foregroundStyle(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .frame(maxWidth: .infinity, minHeight: 32, alignment: .topLeading)
                                    }
                                    .padding(16)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(RideStyle.soft)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                }
                                .accessibilityHint("Choose a destination for \(service.title)")
                            }
                        }
                    }
                    Button { store.beginBooking(reserve: true) } label: {
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: "calendar").font(.system(size: 24, weight: .medium)).accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Reserve").font(.system(size: 17, weight: .semibold))
                                Text("Record a preferred pickup time. Drivers aren't automatically dispatched at that time.")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).padding(.top, 4)
                        }
                        .multilineTextAlignment(.leading)
                        .padding(18)
                        .background(RideStyle.soft)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
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
    }

    private var driverTotals: some View {
        VStack(alignment: .leading, spacing: 24) {
            if store.state == nil {
                if store.errorMessage != nil {
                    Text("Trip totals couldn't be loaded.").font(.headline)
                    Button("Try again") { Task { await store.sync() } }
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 44)
                        .disabled(store.busy)
                } else {
                    ProgressView("Loading recorded trips…").frame(maxWidth: .infinity).padding(.vertical, 30)
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Recorded trip total").font(.system(size: 14, weight: .medium))
                    Text(RideCatalog.money(store.earningsCents))
                        .font(.system(size: 36, weight: .bold))
                        .accessibilityLabel("Recorded trip total, \(RideCatalog.money(store.earningsCents))")
                    Text("Completed ride fares and tip preferences. No payments or payouts are processed.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RideStyle.soft)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                Text("Completed rides").font(.system(size: 20, weight: .bold))
                let trips = store.pastTrips.filter { $0.status == .completed && $0.driver?.id == store.credentials?.participantId }
                if trips.isEmpty {
                    Text("No completed rides yet. Recorded totals will appear here after you finish a ride.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ForEach(trips) { trip in
                    NavigationLink { TripTrackingView(tripID: trip.id) } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(trip.destination.name).font(.system(size: 16, weight: .semibold))
                                Text(RideCatalog.date(trip.createdAt)).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(RideCatalog.money(trip.totalCents)).font(.system(size: 15, weight: .semibold))
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(minHeight: 52)
                        .contentShape(Rectangle())
                    }
                    Divider()
                }
            }
        }
    }
}
