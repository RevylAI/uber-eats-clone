import SwiftUI

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
            }.padding(.vertical, 17).background(disabled ? Color.gray : Color.black).foregroundStyle(.white).clipShape(RoundedRectangle(cornerRadius: 10))
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
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Canvas { context, size in
                    context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.91, green: 0.93, blue: 0.95)))
                    var park = Path()
                    park.move(to: CGPoint(x: size.width * 0.79, y: 0))
                    park.addCurve(to: CGPoint(x: size.width * 0.18, y: size.height), control1: CGPoint(x: size.width * 0.96, y: size.height * 0.45), control2: CGPoint(x: size.width * 0.14, y: size.height * 0.56))
                    park.addLine(to: CGPoint(x: size.width * 0.43, y: size.height))
                    park.addCurve(to: CGPoint(x: size.width * 0.94, y: 0), control1: CGPoint(x: size.width * 0.51, y: size.height * 0.64), control2: CGPoint(x: size.width * 1.08, y: size.height * 0.34))
                    park.closeSubpath()
                    context.fill(park, with: .color(Color(red: 0.70, green: 0.83, blue: 0.72)))
                    for index in 0..<11 {
                        let x = CGFloat(index) * size.width / 8 - size.width * 0.1
                        var street = Path()
                        street.move(to: CGPoint(x: x, y: -20))
                        street.addLine(to: CGPoint(x: x - size.width * 0.24, y: size.height + 20))
                        context.stroke(street, with: .color(.white), lineWidth: index % 3 == 0 ? 8 : 4)
                    }
                    for index in 0..<10 {
                        let y = CGFloat(index) * size.height / 7
                        var street = Path()
                        street.move(to: CGPoint(x: -10, y: y))
                        street.addLine(to: CGPoint(x: size.width + 10, y: y + size.height * 0.12))
                        context.stroke(street, with: .color(.white), lineWidth: index % 3 == 0 ? 8 : 4)
                    }
                    var river = Path()
                    river.move(to: CGPoint(x: -10, y: size.height * 0.71))
                    river.addCurve(to: CGPoint(x: size.width + 10, y: size.height * 0.95), control1: CGPoint(x: size.width * 0.48, y: size.height * 0.48), control2: CGPoint(x: size.width * 0.57, y: size.height * 1.08))
                    context.stroke(river, with: .color(Color(red: 0.63, green: 0.80, blue: 0.89)), style: StrokeStyle(lineWidth: 20, lineCap: .round))
                    if route {
                        var line = Path()
                        line.move(to: CGPoint(x: size.width * 0.25, y: size.height * 0.27))
                        line.addLine(to: CGPoint(x: size.width * 0.57, y: size.height * 0.31))
                        line.addLine(to: CGPoint(x: size.width * 0.49, y: size.height * 0.60))
                        line.addLine(to: CGPoint(x: size.width * 0.77, y: size.height * 0.64))
                        context.stroke(line, with: .color(.white), style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
                        context.stroke(line, with: .color(.black), style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
                    }
                }
                Text("DOWNTOWN").font(.system(size: 10, weight: .medium)).tracking(2).foregroundStyle(.gray).position(x: geometry.size.width * 0.40, y: geometry.size.height * 0.16)
                Text("Congress Ave").font(.system(size: 9)).foregroundStyle(.gray).rotationEffect(.degrees(-73)).position(x: geometry.size.width * 0.32, y: geometry.size.height * 0.49)
                Text("Lady Bird Lake").font(.system(size: 10)).foregroundStyle(Color(red: 0.31, green: 0.49, blue: 0.63)).rotationEffect(.degrees(12)).position(x: geometry.size.width * 0.60, y: geometry.size.height * 0.87)
                if route {
                    Image(systemName: "circle.inset.filled").font(.system(size: 17)).position(x: geometry.size.width * 0.25, y: geometry.size.height * 0.27)
                    Image(systemName: "square.fill").font(.system(size: 14)).position(x: geometry.size.width * 0.77, y: geometry.size.height * 0.64)
                    Text("Pickup spot").font(.system(size: 12, weight: .medium)).padding(7).background(.white).shadow(color: .black.opacity(0.1), radius: 4).position(x: geometry.size.width * 0.27, y: geometry.size.height * 0.37)
                }
                Image(systemName: "car.top.door.front.left.and.front.right.closed.fill")
                    .font(.system(size: 28)).foregroundStyle(.black)
                    .rotationEffect(.degrees(status == .inProgress ? 100 : 20))
                    .position(x: geometry.size.width * (status == .arriving ? 0.30 : status == .inProgress ? 0.64 : 0.52), y: geometry.size.height * (status == .arriving ? 0.30 : 0.60))
            }
        }.clipped().accessibilityElement(children: .ignore).accessibilityLabel(route ? "Austin route" : "Austin map")
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
