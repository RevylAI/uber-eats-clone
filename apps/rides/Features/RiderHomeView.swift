import SwiftUI

struct RiderHomeView: View {
    @EnvironmentObject private var store: RideStore
    @State private var eatsInfo = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Rides").font(.system(size: 38, weight: .medium)).tracking(-2)
                    Spacer()
                }.padding(.top, 6)
                HStack(spacing: 0) {
                    VStack(spacing: 12) {
                        Label("Rides", systemImage: "car.side.fill").font(.system(size: 18, weight: .semibold))
                        Rectangle().frame(height: 3)
                    }.frame(maxWidth: .infinity)
                    Button {
                        if let url = URL(string: "eatsclone://home"), UIApplication.shared.canOpenURL(url) { UIApplication.shared.open(url) }
                        else { eatsInfo = true }
                    } label: {
                        VStack(spacing: 12) {
                            Label("Eats", systemImage: "takeoutbag.and.cup.and.straw.fill").font(.system(size: 18, weight: .semibold))
                            Color.clear.frame(height: 3)
                        }.frame(maxWidth: .infinity)
                    }.foregroundStyle(.secondary)
                }
                HStack(spacing: 10) {
                    Button { store.beginBooking() } label: {
                        HStack(spacing: 12) { Image(systemName: "magnifyingglass"); Text("Where to?").fontWeight(.semibold); Spacer() }
                    }.accessibilityIdentifier("rider.whereTo")
                    Button { store.beginBooking(reserve: true) } label: {
                        HStack(spacing: 5) { Image(systemName: "clock.fill"); Text("Now"); Image(systemName: "chevron.down").font(.system(size: 10)) }.font(.system(size: 13, weight: .semibold)).padding(.horizontal, 11).padding(.vertical, 10).background(.white).clipShape(Capsule())
                    }
                }.padding(14).background(RideStyle.soft).clipShape(Capsule()).foregroundStyle(.black)
                VStack(spacing: 0) {
                    ForEach(Array(RideCatalog.places.dropFirst().prefix(2))) { place in
                        Button { store.beginBooking(destination: place) } label: { RideLocationRow(place: place, icon: "clock.fill") }
                        Divider().padding(.leading, 42)
                    }
                }.padding(.top, -12)
                VStack(alignment: .leading, spacing: 15) {
                    HStack { Text("Suggestions").font(.system(size: 22, weight: .bold)); Spacer(); Button("See all") { store.tab = 1 }.font(.system(size: 13, weight: .medium)) }
                    HStack(spacing: 10) {
                        suggestion("Ride", icon: "car.side.fill") { store.beginBooking() }
                        suggestion("Reserve", icon: "calendar.badge.clock") { store.beginBooking(reserve: true) }
                        suggestion("Comfort", icon: "car.side.hill.up.fill") { store.beginBooking(); store.draft.service = .comfort }
                        suggestion("Saved", icon: "star.fill") { store.tab = 3 }
                    }
                }
                Button { store.beginBooking(reserve: true) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 13) {
                            Text("Go on your time").font(.system(size: 24, weight: .bold))
                            Text("Reserve your ride ahead.\nOne less thing to think about.").font(.system(size: 14)).multilineTextAlignment(.leading)
                            Label("Explore Reserve", systemImage: "arrow.right").font(.system(size: 13, weight: .semibold)).labelStyle(.titleAndIcon)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "calendar").font(.system(size: 68, weight: .thin)).rotationEffect(.degrees(-12))
                    }.padding(22).frame(maxWidth: .infinity, alignment: .leading).background(Color(red: 0.86, green: 0.91, blue: 0.96)).clipShape(RoundedRectangle(cornerRadius: 14))
                }.foregroundStyle(.black)
                VStack(alignment: .leading, spacing: 13) {
                    Text("A little comfort goes a long way").font(.system(size: 22, weight: .bold))
                    HStack {
                        RideCarArt(service: .comfort)
                        VStack(alignment: .leading, spacing: 6) { Text("Room to relax").font(.headline); Text("Extra legroom. A quieter ride.").font(.subheadline).foregroundStyle(.secondary) }
                        Spacer()
                    }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(RideStyle.soft).clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }.padding(.horizontal, 20)
        }.background(.white)
            .alert("Eats isn't installed", isPresented: $eatsInfo) { Button("OK", role: .cancel) {} } message: { Text("Install Eats to open it from here.") }
    }

    private func suggestion(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 28, weight: .regular)).frame(height: 34)
                Text(title).font(.system(size: 11, weight: .medium))
            }.frame(maxWidth: .infinity).padding(.vertical, 15).background(RideStyle.soft).clipShape(RoundedRectangle(cornerRadius: 11))
        }.foregroundStyle(.black)
    }
}

struct RideServicesView: View {
    @EnvironmentObject private var store: RideStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(store.role == .driver ? "Earnings" : "Services").font(.system(size: 32, weight: .bold)).padding(.top, 12)
                if store.role == .driver {
                    Text("Recent trip totals").font(.headline)
                    Text(RideCatalog.money(store.earningsCents)).font(.system(size: 46, weight: .bold))
                    Text("Recorded totals for your completed rides. Payouts are unavailable.").foregroundStyle(.secondary)
                    ForEach(store.pastTrips.filter { $0.status == .completed && $0.driver?.id == store.credentials?.participantId }) { trip in
                        HStack { VStack(alignment: .leading) { Text(trip.destination.name).font(.headline); Text(RideCatalog.date(trip.createdAt)).font(.caption).foregroundStyle(.secondary) }; Spacer(); Text(RideCatalog.money(trip.totalCents)).fontWeight(.semibold) }.padding(.vertical, 10)
                        Divider()
                    }
                } else {
                    Text("Go anywhere").font(.title3.bold())
                    LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 14) {
                        ForEach(RideService.allCases) { service in
                            Button { store.beginBooking(); store.draft.service = service } label: {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack { Spacer(); RideCarArt(service: service) }
                                    Text(service.title).font(.headline)
                                    Text(service.detail).font(.caption).foregroundStyle(.secondary).frame(height: 32, alignment: .top)
                                }.frame(maxWidth: .infinity, alignment: .leading).padding(16).background(RideStyle.soft).clipShape(RoundedRectangle(cornerRadius: 12))
                            }.foregroundStyle(.black)
                        }
                    }
                    Button { store.beginBooking(reserve: true) } label: { Label("Reserve a ride", systemImage: "calendar.badge.clock").font(.headline).frame(maxWidth: .infinity, alignment: .leading).padding(20).background(RideStyle.soft).clipShape(RoundedRectangle(cornerRadius: 12)) }.foregroundStyle(.black)
                }
            }.padding(20)
        }.navigationBarTitleDisplayMode(.inline)
    }
}
