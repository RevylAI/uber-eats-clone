import SwiftUI

private enum DiscoveryCuisine: String, CaseIterable, Identifiable {
    case all = "All"
    case burgers = "Burgers"
    case pizza = "Pizza"
    case sushi = "Sushi"
    case mexican = "Mexican"
    case healthy = "Healthy"
    case bakery = "Bakery"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .all: return "🍽️"
        case .burgers: return "🍔"
        case .pizza: return "🍕"
        case .sushi: return "🍣"
        case .mexican: return "🌮"
        case .healthy: return "🥗"
        case .bakery: return "🥐"
        }
    }

    var image: String {
        switch self {
        case .all, .burgers: return "burger"
        case .pizza: return "pizza"
        case .sushi: return "sushi"
        case .mexican: return "tacos"
        case .healthy: return "salad"
        case .bakery: return "dessert"
        }
    }

    func matches(_ restaurant: Restaurant) -> Bool {
        self == .all || restaurant.cuisine.localizedCaseInsensitiveContains(rawValue)
    }
}

private func discoveryMatches(_ restaurant: Restaurant, query: String) -> Bool {
    let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
    return search.isEmpty || restaurant.name.localizedCaseInsensitiveContains(search)
        || restaurant.cuisine.localizedCaseInsensitiveContains(search)
        || restaurant.menu.contains { $0.name.localizedCaseInsensitiveContains(search) }
}

private func hasDiscoveryOffer(_ restaurant: Restaurant) -> Bool {
    restaurant.offer.localizedCaseInsensitiveContains("free") || restaurant.offer.contains("$")
}

struct HomeView: View {
    @EnvironmentObject private var store: AppStore
    @State private var query = ""
    @State private var cuisine: DiscoveryCuisine = .all
    @State private var offersOnly = false
    @State private var quickOnly = false
    @State private var favoritesOnly = false
    @State private var showingAddress = false

    private var results: [Restaurant] {
        store.restaurants.filter { restaurant in
            cuisine.matches(restaurant) && discoveryMatches(restaurant, query: query)
                && (!offersOnly || hasDiscoveryOffer(restaurant))
                && (!quickOnly || restaurant.minutes == "10–20" || restaurant.minutes == "15–25" || restaurant.minutes == "20–30")
                && (!favoritesOnly || store.snapshot.favorites.contains(restaurant.id))
        }
    }

    private var isExploring: Bool {
        query.isEmpty && cuisine == .all && !offersOnly && !quickOnly && !favoritesOnly
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    addressHeader
                        .padding(.horizontal, 20)
                    DiscoveryModePicker()
                        .padding(.horizontal, 20)
                    DiscoverySearchField(text: $query, prompt: "Search food and restaurants")
                        .padding(.horizontal, 20)
                    cuisinePicker
                    filterPicker
                    if isExploring {
                        promotionalPanel {
                            withAnimation {
                                offersOnly = true
                                proxy.scrollTo("restaurant-results", anchor: .top)
                            }
                        }
                        .padding(.horizontal, 20)
                        featuredSection
                    }
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(isExploring ? "Loved by locals" : "Made for your cravings")
                                .font(.system(size: 25, weight: .bold))
                            Spacer()
                            Text("\(results.count) places")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        if results.isEmpty {
                            DiscoveryEmptyState(query: query) { resetFilters() }
                        } else {
                            ForEach(results) { restaurant in
                                DiscoveryRestaurantCard(restaurant: restaurant)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .id("restaurant-results")
                }
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(.white)
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showingAddress) {
            NavigationStack {
                AddressView()
            }
            .environmentObject(store)
        }
        .tint(.black)
    }

    private var addressHeader: some View {
        HStack(spacing: 16) {
            Button { showingAddress = true } label: {
                VStack(alignment: .leading, spacing: 5) {
                    Text(store.mode == .delivery ? "DELIVER TO" : "PICK UP NEAR")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.7)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        Text(store.profile.address.components(separatedBy: ",").first ?? store.profile.address)
                            .font(.system(size: 19, weight: .bold))
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                    }
                }
                .foregroundStyle(.black)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Change delivery address, \(store.profile.address)")
            Spacer(minLength: 0)
            Button {
                withAnimation { favoritesOnly.toggle() }
            } label: {
                Image(systemName: favoritesOnly ? "heart.fill" : "heart")
                    .font(.system(size: 20, weight: .medium))
                    .frame(width: 46, height: 46)
                    .background(EatsTheme.gray, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(favoritesOnly ? "Show all restaurants" : "Show favorite restaurants")
        }
    }

    private var cuisinePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 17) {
                ForEach(DiscoveryCuisine.allCases) { category in
                    Button {
                        withAnimation { cuisine = category }
                    } label: {
                        VStack(spacing: 8) {
                            Text(category.emoji)
                                .font(.system(size: 31))
                                .frame(width: 58, height: 58)
                                .background(cuisine == category ? EatsTheme.pale : EatsTheme.gray, in: RoundedRectangle(cornerRadius: 20))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(cuisine == category ? EatsTheme.green : .clear, lineWidth: 1.5)
                                }
                            Text(category.rawValue)
                                .font(.system(size: 12, weight: cuisine == category ? .bold : .medium))
                        }
                        .foregroundStyle(.black)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(cuisine == category ? [.isSelected] : [])
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var filterPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                DiscoveryFilter(title: "Offers", symbol: "tag", selected: offersOnly) { offersOnly.toggle() }
                DiscoveryFilter(title: "30 min or less", symbol: "clock", selected: quickOnly) { quickOnly.toggle() }
                DiscoveryFilter(title: "Favorites", symbol: "heart", selected: favoritesOnly) { favoritesOnly.toggle() }
            }
            .padding(.horizontal, 20)
        }
    }

    private func promotionalPanel(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("GOOD FOOD. GREAT MOOD.")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(1.3)
                    Text("Your lunch.\nUpgraded.")
                        .font(.system(size: 30, weight: .heavy))
                        .tracking(-1)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Big cravings, little prices.")
                        .font(.system(size: 12, weight: .medium))
                    HStack(spacing: 7) {
                        Text("Explore offers")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 13)
                    .padding(.vertical, 10)
                    .foregroundStyle(.black)
                    .background(.white, in: Capsule())
                }
                .padding(.vertical, 23)
                .padding(.leading, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
                FoodImage(name: "burger", height: 230)
                    .frame(width: 145)
                    .mask {
                        LinearGradient(colors: [.clear, .black, .black], startPoint: .leading, endPoint: .trailing)
                    }
            }
            .foregroundStyle(.white)
            .background(EatsTheme.green)
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }

    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("A little local love")
                        .font(.system(size: 25, weight: .bold))
                    Text("Neighborhood favorites, delivered.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 37, height: 37)
                    .background(EatsTheme.gray, in: Circle())
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 20)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(Array(store.restaurants.prefix(4))) { restaurant in
                        DiscoveryRestaurantCard(restaurant: restaurant, compact: true)
                            .frame(width: 270)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func resetFilters() {
        query = ""
        cuisine = .all
        offersOnly = false
        quickOnly = false
        favoritesOnly = false
    }
}

struct BrowseView: View {
    @EnvironmentObject private var store: AppStore
    @State private var query = ""
    @State private var cuisine: DiscoveryCuisine = .all

    private var results: [Restaurant] {
        store.restaurants.filter { cuisine.matches($0) && discoveryMatches($0, query: query) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Find your craving")
                        .font(.system(size: 32, weight: .bold))
                        .tracking(-0.9)
                    Text("Something delicious is just around the corner.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                DiscoverySearchField(text: $query, prompt: "Search restaurants, dishes, cuisines")
                if query.isEmpty && cuisine == .all {
                    Text("What sounds good?")
                        .font(.system(size: 23, weight: .bold))
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        ForEach(DiscoveryCuisine.allCases.filter { $0 != .all }) { category in
                            Button { cuisine = category } label: {
                                VStack(alignment: .leading, spacing: 0) {
                                    FoodImage(name: category.image, height: 110)
                                    HStack {
                                        Text(category.rawValue)
                                            .font(.system(size: 16, weight: .bold))
                                        Spacer(minLength: 0)
                                        Image(systemName: "arrow.up.right")
                                            .font(.system(size: 12, weight: .semibold))
                                    }
                                    .padding(13)
                                }
                                .foregroundStyle(.black)
                                .background(EatsTheme.gray)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                HStack {
                    Text(cuisine == .all ? (query.isEmpty ? "Explore nearby" : "Search results") : cuisine.rawValue)
                        .font(.system(size: 24, weight: .bold))
                    Spacer()
                    if cuisine != .all {
                        Button("Show all") { cuisine = .all }
                            .font(.system(size: 13, weight: .semibold))
                    } else {
                        Text("\(results.count) places")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }
                if results.isEmpty {
                    DiscoveryEmptyState(query: query) {
                        query = ""
                        cuisine = .all
                    }
                } else {
                    LazyVStack(spacing: 24) {
                        ForEach(results) { restaurant in
                            DiscoveryRestaurantCard(restaurant: restaurant)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(.white)
        .toolbar(.hidden, for: .navigationBar)
        .tint(.black)
    }
}

struct RestaurantView: View {
    @EnvironmentObject private var store: AppStore
    let restaurant: Restaurant
    @State private var selectedItem: MenuItem?
    @State private var selectedSection = "Most popular"

    private var categories: [String] {
        restaurant.menu.reduce(into: [String]()) { result, item in
            if !result.contains(item.category) { result.append(item.category) }
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    FoodImage(name: restaurant.image, height: 250)
                        .overlay(alignment: .bottomLeading) {
                            Label("A neighborhood favorite", systemImage: "seal.fill")
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(.white, in: Capsule())
                                .padding(20)
                        }
                    restaurantInformation
                    Section {
                        ForEach(categories, id: \.self) { category in
                            VStack(alignment: .leading, spacing: 0) {
                                Text(category)
                                    .font(.system(size: 25, weight: .bold))
                                    .padding(.top, 26)
                                    .padding(.bottom, 8)
                                ForEach(restaurant.menu.filter { $0.category == category }) { item in
                                    Button { selectedItem = item } label: {
                                        menuRow(item)
                                    }
                                    .buttonStyle(.plain)
                                    Divider()
                                }
                            }
                            .padding(.horizontal, 20)
                            .id(category)
                        }
                    } header: {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 22) {
                                ForEach(categories, id: \.self) { category in
                                    Button {
                                        selectedSection = category
                                        withAnimation { proxy.scrollTo(category, anchor: .top) }
                                    } label: {
                                        Text(category)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(selectedSection == category ? .black : .secondary)
                                            .padding(.vertical, 16)
                                            .overlay(alignment: .bottom) {
                                                if selectedSection == category {
                                                    Rectangle().fill(.black).frame(height: 3)
                                                }
                                            }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        .background(.white)
                        .overlay(alignment: .bottom) { Divider() }
                    }
                }
                .padding(.bottom, 24)
            }
            .background(.white)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(restaurant.name).font(.system(size: 15, weight: .semibold)).lineLimit(1)
            }
            ToolbarItem(placement: .topBarTrailing) {
                DiscoveryFavoriteButton(restaurant: restaurant)
            }
        }
        .sheet(item: $selectedItem) { item in
            ItemDetailView(item: item, restaurant: restaurant)
                .environmentObject(store)
        }
        .tint(.black)
    }

    private var restaurantInformation: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 9) {
                Text(restaurant.name)
                    .font(.system(size: 32, weight: .bold))
                    .tracking(-0.8)
                HStack(spacing: 5) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11))
                    Text(restaurant.rating).fontWeight(.semibold)
                    Text("• \(restaurant.cuisine)").foregroundStyle(.secondary)
                }
                .font(.system(size: 12))
                .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 10) {
                Image(systemName: "tag.fill")
                Text(restaurant.offer)
                    .font(.system(size: 13, weight: .semibold))
                Spacer(minLength: 0)
            }
            .foregroundStyle(EatsTheme.green)
            .padding(14)
            .background(EatsTheme.pale, in: RoundedRectangle(cornerRadius: 10))
            DiscoveryModePicker()
            HStack {
                VStack(spacing: 5) {
                    Text(store.mode == .pickup ? "No fee" : (store.profile.uberOne ? "$0.00" : restaurant.deliveryFee.money))
                        .font(.system(size: 17, weight: .bold))
                    Text(store.mode == .pickup ? "Pickup" : "Delivery fee")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                Rectangle().fill(EatsTheme.gray).frame(width: 1, height: 34)
                VStack(spacing: 5) {
                    Text("\(restaurant.minutes) min")
                        .font(.system(size: 17, weight: .bold))
                    Text(store.mode == .pickup ? "Estimated preparation" : "Estimated arrival")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 5)
        }
        .padding(20)
    }

    private func menuRow(_ item: MenuItem) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 7) {
                if item.popular {
                    Text("MOST LOVED")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(0.8)
                        .foregroundStyle(EatsTheme.green)
                }
                Text(item.name)
                    .font(.system(size: 17, weight: .semibold))
                Text(item.price.money)
                    .font(.system(size: 14))
                Text(item.detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            FoodImage(name: item.image, height: 112)
                .frame(width: 112)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 33, height: 33)
                        .background(.white, in: Circle())
                        .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
                        .padding(7)
                }
        }
        .foregroundStyle(.black)
        .padding(.vertical, 18)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.name), \(item.price.money). Customize item")
    }
}

struct ItemDetailView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let item: MenuItem
    let restaurant: Restaurant
    @State private var size: String?
    @State private var extras: Set<String> = []
    @State private var note = ""
    @State private var quantity = 1
    @State private var showingReplaceConfirmation = false

    private let availableExtras: [(name: String, price: Int)] = [
        ("Extra cheese", 150), ("Avocado", 200), ("Bacon", 250)
    ]

    private var extraPrice: Int {
        (size == "Large" ? 200 : 0) + availableExtras.filter { extras.contains($0.name) }.reduce(0) { $0 + $1.price }
    }

    private var options: [String] {
        [size ?? "Regular"] + availableExtras.filter { extras.contains($0.name) }.map(\.name)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    FoodImage(name: item.image, height: 275)
                    VStack(alignment: .leading, spacing: 12) {
                        if item.popular {
                            Label("A crowd favorite", systemImage: "hand.thumbsup.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(EatsTheme.green)
                        }
                        Text(item.name)
                            .font(.system(size: 30, weight: .bold))
                            .tracking(-0.7)
                        Text(item.price.money)
                            .font(.system(size: 19, weight: .medium))
                        Text(item.detail)
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                            .lineSpacing(4)
                    }
                    .padding(20)
                    customizationHeading("Choose your size", subtitle: "Choose 1", required: true)
                    VStack(spacing: 0) {
                        sizeRow("Regular", price: 0)
                        Divider()
                        sizeRow("Large", price: 200)
                    }
                    .padding(.horizontal, 20)
                    customizationHeading("Make it yours", subtitle: "Add a little extra", required: false)
                    VStack(spacing: 0) {
                        ForEach(availableExtras, id: \.name) { extra in
                            Button {
                                if extras.contains(extra.name) { extras.remove(extra.name) }
                                else { extras.insert(extra.name) }
                            } label: {
                                HStack {
                                    Text(extra.name)
                                    Spacer()
                                    Text("+\(extra.price.money)")
                                        .foregroundStyle(.secondary)
                                    Image(systemName: extras.contains(extra.name) ? "checkmark.square.fill" : "square")
                                        .font(.system(size: 23, weight: .light))
                                        .foregroundStyle(extras.contains(extra.name) ? EatsTheme.green : .black)
                                        .padding(.leading, 8)
                                }
                                .font(.system(size: 15))
                                .foregroundStyle(.black)
                                .padding(.vertical, 18)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(extras.contains(extra.name) ? [.isSelected] : [])
                            Divider()
                        }
                    }
                    .padding(.horizontal, 20)
                    customizationHeading("Special instructions", subtitle: "Saved with your demo order", required: false)
                    TextField("Any requests? Let us know.", text: $note, axis: .vertical)
                        .font(.system(size: 15))
                        .lineLimit(3...5)
                        .padding(15)
                        .background(EatsTheme.gray, in: RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    HStack {
                        Text("Quantity").font(.system(size: 20, weight: .bold))
                        Spacer()
                        quantityButton(symbol: "minus", disabled: quantity == 1) { quantity -= 1 }
                        Text("\(quantity)")
                            .font(.system(size: 19, weight: .semibold))
                            .monospacedDigit()
                            .frame(minWidth: 32)
                            .accessibilityLabel("Quantity \(quantity)")
                        quantityButton(symbol: "plus", disabled: quantity == 20) { quantity += 1 }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .background(.white)
            .navigationTitle("Customize your order")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .frame(width: 30, height: 30)
                            .background(EatsTheme.gray, in: Circle())
                    }
                    .accessibilityLabel("Close customization")
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 8) {
                    if size == nil {
                        Text("Select a size to continue")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    BlackButton(title: "Add \(quantity) to cart · \(((item.price + extraPrice) * quantity).money)") {
                        addToCart()
                    }
                    .disabled(size == nil)
                    .opacity(size == nil ? 0.35 : 1)
                }
                .padding(16)
                .background(.white)
                .overlay(alignment: .top) { Divider() }
            }
            .alert("Start a new cart?", isPresented: $showingReplaceConfirmation) {
                Button("Keep current cart", role: .cancel) {}
                Button("Replace cart", role: .destructive) { addToCart(replace: true) }
            } message: {
                Text("Your cart has items from \(store.cartRestaurant?.name ?? "another restaurant"). Replace them with your order from \(restaurant.name)?")
            }
        }
        .tint(.black)
    }

    private func customizationHeading(_ title: String, subtitle: String, required: Bool) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 21, weight: .bold))
                Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
            Text(required ? "Required" : "Optional")
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(required ? EatsTheme.pale : EatsTheme.gray, in: Capsule())
                .foregroundStyle(required ? EatsTheme.green : .secondary)
        }
        .padding(20)
        .background(EatsTheme.gray.opacity(0.55))
    }

    private func sizeRow(_ title: String, price: Int) -> some View {
        Button { size = title } label: {
            HStack {
                Text(title)
                Spacer()
                Text(price == 0 ? "Included" : "+\(price.money)")
                    .foregroundStyle(.secondary)
                Image(systemName: size == title ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(size == title ? EatsTheme.green : .black)
                    .padding(.leading, 8)
            }
            .font(.system(size: 15))
            .foregroundStyle(.black)
            .padding(.vertical, 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(size == title ? [.isSelected] : [])
    }

    private func quantityButton(symbol: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 44, height: 44)
                .background(EatsTheme.gray, in: Circle())
        }
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
        .accessibilityLabel(symbol == "minus" ? "Decrease quantity" : "Increase quantity")
    }

    private func addToCart(replace: Bool = false) {
        guard size != nil else { return }
        if store.add(item, restaurant: restaurant, quantity: quantity, options: options, extraPrice: extraPrice, note: note.trimmingCharacters(in: .whitespacesAndNewlines), replace: replace) {
            dismiss()
        } else {
            showingReplaceConfirmation = true
        }
    }
}

private struct DiscoveryModePicker: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        HStack(spacing: 4) {
            ForEach(DeliveryMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { store.mode = mode }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: mode == .delivery ? "bicycle" : "bag")
                        Text(mode.rawValue)
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .foregroundStyle(store.mode == mode ? .white : .black)
                    .background(store.mode == mode ? Color.black : .clear, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(store.mode == mode ? [.isSelected] : [])
            }
        }
        .padding(4)
        .background(EatsTheme.gray, in: Capsule())
    }
}

private struct DiscoverySearchField: View {
    @Binding var text: String
    let prompt: String

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 19, weight: .medium))
            TextField(prompt, text: $text)
                .font(.system(size: 14))
                .submitLabel(.search)
                .autocorrectionDisabled()
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(EatsTheme.gray, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct DiscoveryFilter: View {
    let title: String
    let symbol: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .foregroundStyle(selected ? .white : .black)
                .background(selected ? Color.black : EatsTheme.gray, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

private struct DiscoveryRestaurantCard: View {
    @EnvironmentObject private var store: AppStore
    let restaurant: Restaurant
    var compact = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            NavigationLink {
                RestaurantView(restaurant: restaurant)
            } label: {
                VStack(alignment: .leading, spacing: 10) {
                    FoodImage(name: restaurant.image, height: compact ? 150 : 190)
                        .overlay(alignment: .bottomLeading) {
                            if hasDiscoveryOffer(restaurant) {
                                Text(restaurant.offer)
                                    .font(.system(size: 11, weight: .bold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .foregroundStyle(EatsTheme.green)
                                    .background(EatsTheme.pale, in: Capsule())
                                    .padding(11)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(restaurant.name)
                                .font(.system(size: compact ? 16 : 18, weight: .bold))
                                .lineLimit(1)
                            Text("\(restaurant.cuisine) · \(restaurant.minutes) min")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Text(store.mode == .pickup ? "Pickup · No delivery fee" : "\(store.profile.uberOne ? "$0.00" : restaurant.deliveryFee.money) delivery fee")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        Text(restaurant.rating.components(separatedBy: " ").first ?? restaurant.rating)
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 34, height: 34)
                            .background(EatsTheme.gray, in: Circle())
                    }
                }
                .foregroundStyle(.black)
            }
            .buttonStyle(.plain)
            DiscoveryFavoriteButton(restaurant: restaurant)
                .padding(10)
        }
    }
}

private struct DiscoveryFavoriteButton: View {
    @EnvironmentObject private var store: AppStore
    let restaurant: Restaurant

    private var isFavorite: Bool { store.snapshot.favorites.contains(restaurant.id) }

    var body: some View {
        Button { store.toggleFavorite(restaurant.id) } label: {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(isFavorite ? EatsTheme.green : .black)
                .frame(width: 38, height: 38)
                .background(.white, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(isFavorite ? "Remove" : "Save") \(restaurant.name) \(isFavorite ? "from" : "to") favorites")
    }
}

private struct DiscoveryEmptyState: View {
    let query: String
    let reset: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32, weight: .light))
                .frame(width: 78, height: 78)
                .background(EatsTheme.pale, in: Circle())
            Text("No bites just yet")
                .font(.system(size: 22, weight: .bold))
            Text(query.isEmpty ? "Try a different filter to find your next favorite." : "We couldn’t find “\(query)”. Try a restaurant, dish, or cuisine.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Explore all restaurants", action: reset)
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .foregroundStyle(.white)
                .background(.black, in: Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 35)
        .padding(.horizontal, 18)
    }
}
