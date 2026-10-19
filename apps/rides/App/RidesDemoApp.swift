import SwiftUI

@main
struct RidesDemoApp: App {
    @StateObject private var store = RideStore()
    var body: some Scene {
        WindowGroup {
            RideRootView()
                .environmentObject(store)
                .preferredColorScheme(.light)
                .onOpenURL { url in Task { await store.handle(url) } }
        }
    }
}

struct RideRootView: View {
    @EnvironmentObject private var store: RideStore
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        VStack(spacing: 0) {
            if let status = store.revylStatus {
                Text(status).font(.caption2).frame(maxWidth: .infinity).padding(5).background(Color.yellow.opacity(0.22))
            }
            if let error = store.errorMessage {
                HStack(alignment: .top) {
                    Image(systemName: "exclamationmark.circle.fill")
                    Text(error).frame(maxWidth: .infinity, alignment: .leading)
                    if store.connected {
                        Button("Retry") { Task { await store.sync() } }.fontWeight(.semibold)
                    }
                    Button { store.errorMessage = nil } label: { Image(systemName: "xmark") }.accessibilityLabel("Dismiss error")
                }.font(.caption).padding(12).background(Color.red.opacity(0.08)).foregroundStyle(.red)
            }
            TabView(selection: $store.tab) {
                NavigationStack {
                    Group {
                        if store.role == .driver { DriverHomeView() }
                        else if let trip = store.activeTrip ?? store.focusedTrip { TripTrackingView(tripID: trip.id) }
                        else { RiderHomeView() }
                    }
                    .toolbar(.hidden, for: .navigationBar)
                }.tabItem { Label("Home", systemImage: "house.fill") }.tag(0)
                NavigationStack { RideServicesView() }.tabItem { Label(store.role == .driver ? "Earnings" : "Services", systemImage: store.role == .driver ? "chart.bar.fill" : "square.grid.3x3.fill") }.tag(1)
                NavigationStack { RideActivityView() }.tabItem { Label("Activity", systemImage: "receipt.fill") }.tag(2)
                NavigationStack { RideAccountView() }.tabItem { Label("Account", systemImage: "person.fill") }.tag(3)
            }.tint(.black)
        }
        .sheet(isPresented: $store.showConnection) { DemoConnectionView().environmentObject(store) }
        .fullScreenCover(isPresented: $store.showBooking) { BookingFlowView().environmentObject(store) }
        .task(id: scenePhase == .active ? store.credentials?.token : nil) {
            if scenePhase == .active { await store.runUpdates() }
        }
    }
}
