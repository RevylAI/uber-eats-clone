// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "RidesDemoCore",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "RidesDemo", targets: ["RidesDemo"])],
    dependencies: [.package(url: "https://github.com/get-convex/convex-swift", exact: "0.8.1")],
    targets: [
        .target(name: "RidesDemo", dependencies: [.product(name: "ConvexMobile", package: "convex-swift")], path: "Core"),
        .testTarget(name: "RidesDemoTests", dependencies: ["RidesDemo"], path: "Tests")
    ]
)
