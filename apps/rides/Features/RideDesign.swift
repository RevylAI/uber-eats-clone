import SwiftUI
import MapKit

enum RideStyle {
    static let soft = Color(red: 0.95, green: 0.95, blue: 0.95)
    static let green = Color(red: 0.02, green: 0.44, blue: 0.27)
}

struct RidePrimaryButton: View {
    var title: String
    var busy = false
    var disabled = false
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack {
                Spacer()
                if busy { ProgressView().tint(.white) }
                Text(title).font(.system(size: 17, weight: .semibold))
                Spacer()
            }.padding(.vertical, 17).background(disabled ? RideStyle.soft : Color.black).foregroundStyle(disabled ? Color.secondary : Color.white).clipShape(RoundedRectangle(cornerRadius: 12))
        }.disabled(disabled || busy)
    }
}

struct RideCarArt: View {
    var service: RideService = .uberX
    var body: some View {
        ZStack(alignment: .bottom) {
            Ellipse().fill(.black.opacity(0.10)).frame(width: 74, height: 10).blur(radius: 3).offset(y: 3)
            Image(systemName: service.icon)
                .font(.system(size: 48, weight: .regular))
                .foregroundStyle(service == .black ? Color.black.gradient : Color(white: 0.56).gradient)
                .shadow(color: .black.opacity(0.14), radius: 2, x: 1, y: 3)
            if service == .green { Image(systemName: "leaf.fill").font(.system(size: 13)).foregroundStyle(RideStyle.green).offset(x: 27, y: -29) }
            if service == .pet { Image(systemName: "pawprint.fill").font(.system(size: 13)).offset(x: 28, y: -29) }
        }.frame(width: 84, height: 54).accessibilityHidden(true)
    }
}

struct DemoMapView: View {
    var route = true
    var status: TripStatus = .requested
    var pickup: DemoPlace = RideCatalog.places[0]
    var destination: DemoPlace = RideCatalog.places[1]
    var stops: [DemoPlace] = []

    private var routePlaces: [DemoPlace] { [pickup] + stops + [destination] }

    private var cameraRect: MKMapRect {
        let points = routePlaces.map { MKMapPoint(CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)) }
        let bounds = points.reduce(MKMapRect.null) { $0.union(MKMapRect(origin: $1, size: MKMapSize(width: 1, height: 1))) }
        let width = max(bounds.width * 1.5, 12_000)
        let height = max(bounds.height * 1.6, 12_000)
        return MKMapRect(x: bounds.midX - width / 2, y: bounds.midY - height / 2, width: width, height: height)
    }

    var body: some View {
        Map(initialPosition: route ? .rect(cameraRect) : .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: pickup.latitude, longitude: pickup.longitude), span: MKCoordinateSpan(latitudeDelta: 0.035, longitudeDelta: 0.035))), interactionModes: []) {
            if route {
                MapPolyline(coordinates: routePlaces.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) })
                    .stroke(.black, style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [6, 5]))
                Annotation("Pickup", coordinate: CLLocationCoordinate2D(latitude: pickup.latitude, longitude: pickup.longitude)) {
                    Image(systemName: "circle.inset.filled").font(.system(size: 20)).foregroundStyle(.black)
                        .padding(6).background(.white).clipShape(Circle()).shadow(color: .black.opacity(0.12), radius: 3)
                }
                ForEach(stops) { stop in
                    Annotation(stop.name, coordinate: CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude)) {
                        Image(systemName: "circle").font(.system(size: 15, weight: .bold)).foregroundStyle(.black)
                            .padding(5).background(.white).clipShape(Circle())
                    }
                }
                Annotation("Dropoff", coordinate: CLLocationCoordinate2D(latitude: destination.latitude, longitude: destination.longitude)) {
                    Image(systemName: "square.fill").font(.system(size: 14)).foregroundStyle(.white)
                        .padding(8).background(.black).clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
        .id(route ? routePlaces.map(\.id).joined(separator: "-") : pickup.id)
        .overlay(alignment: .topTrailing) {
            if route {
                Text("Route preview").font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(.white).clipShape(Capsule()).padding(12)
            }
        }
        .clipped().accessibilityElement(children: .contain)
        .accessibilityLabel(route ? "\(status.title). Route preview from \(pickup.name) to \(destination.name). Straight-line connections, not driving directions or live vehicle tracking." : "Map of Austin. Live vehicle tracking is unavailable.")
    }
}

struct RideLocationRow: View {
    let place: DemoPlace
    var icon = "mappin.circle.fill"
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 20)).frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(place.name).font(.system(size: 16, weight: .medium)).foregroundStyle(.black).lineLimit(2)
                Text(place.address).font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 0)
        }.padding(.vertical, 12).contentShape(Rectangle())
    }
}

struct RideRouteSummary: View {
    let pickup: DemoPlace
    let destination: DemoPlace
    var stops: [DemoPlace] = []
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RideLocationRow(place: pickup, icon: "circle.inset.filled")
            ForEach(stops) { RideLocationRow(place: $0, icon: "circle") }
            RideLocationRow(place: destination, icon: "square.fill")
        }
    }
}

struct RideInfoView: View {
    let title: String
    let icon: String
    let text: String
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Image(systemName: icon).font(.system(size: 44)).padding(.top, 20)
                Text(title).font(.largeTitle.bold())
                Text(text).font(.body).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(20)
        }.navigationTitle(title).navigationBarTitleDisplayMode(.inline)
    }
}
