// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RidesDemoCore",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "RidesDemo", targets: ["RidesDemo"])],
    targets: [
        .target(name: "RidesDemo", path: "Core"),
        .testTarget(name: "RidesDemoTests", dependencies: ["RidesDemo"], path: "Tests")
    ]
)
