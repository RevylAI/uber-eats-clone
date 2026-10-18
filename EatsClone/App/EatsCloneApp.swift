import SwiftUI

@main
struct EatsCloneApp: App {
    @StateObject private var store = AppStore()
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store).tint(.black).preferredColorScheme(.light)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showTracking = false

    var body: some View {
        TabView(selection: $store.selectedTab) {
            CartNavigation { HomeView() }.tabItem { Label("Home", systemImage: "house.fill") }.tag(0)
            CartNavigation { BrowseView() }.tabItem { Label("Browse", systemImage: "magnifyingglass") }.tag(1)
            CartNavigation { OrdersView() }.tabItem { Label("Orders", systemImage: "receipt") }.tag(2)
            CartNavigation { AccountView() }.tabItem { Label("Account", systemImage: "person.crop.circle") }.tag(3)
        }
        .sheet(isPresented: $store.showCart, onDismiss: {
            if store.activeOrderID != nil { showTracking = true }
        }) { NavigationStack { CartView() }.environmentObject(store) }
        .sheet(isPresented: $showTracking, onDismiss: { store.activeOrderID = nil }) {
            if let id = store.activeOrderID {
                NavigationStack { OrderTrackingView(orderID: id).toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { showTracking = false } } } }.environmentObject(store)
            }
        }
        .fullScreenCover(isPresented: Binding(get: { !store.snapshot.onboarded }, set: { if !$0 { store.snapshot.onboarded = true } })) {
            WelcomeView().environmentObject(store)
        }
    }
}

struct CartNavigation<Content: View>: View {
    @EnvironmentObject private var store: AppStore
    @ViewBuilder var content: () -> Content
    var body: some View {
        NavigationStack { content() }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !store.cart.isEmpty {
                    Button { store.showCart = true } label: {
                        HStack {
                            Text("\(store.cartCount)").font(.subheadline.bold()).padding(7).background(.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 6))
                            Spacer()
                            Text("View cart").font(.headline)
                            Spacer()
                            Text(store.subtotal.money).font(.subheadline.bold())
                        }.foregroundStyle(.white).padding(12).background(.black, in: RoundedRectangle(cornerRadius: 12))
                    }.padding(.horizontal, 16).padding(.vertical, 6).background(.white)
                }
            }
    }
}

struct WelcomeView: View {
    @EnvironmentObject private var store: AppStore
    @State private var started = false
    var body: some View {
        if started {
            LocalOnboardingView()
        } else {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 0) { Text("Eats").font(.system(size: 38, weight: .black)); Text(" / local").font(.system(size: 24, weight: .medium)).foregroundStyle(EatsTheme.green) }
                .padding(.top, 24)
            Spacer()
            FoodImage(name: "burger", height: 300).clipShape(RoundedRectangle(cornerRadius: 26))
            Text("Good food.\nYour neighborhood.").font(.system(size: 44, weight: .bold, design: .default)).tracking(-1.8)
            Text("Your next favorite is just around the corner.").font(.title3).foregroundStyle(.secondary)
            Spacer()
            Label("A fully offline, independent demo", systemImage: "iphone").font(.subheadline).foregroundStyle(EatsTheme.green)
            BlackButton(title: "Get started") { started = true }
            Button("Explore with demo profile") { store.snapshot.onboarded = true }.font(.subheadline.bold()).frame(maxWidth: .infinity)
        }.padding(24).background(Color.white)
        }
    }
}
