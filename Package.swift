// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EatsCloneCore",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "EatsClone", targets: ["EatsClone"])],
    targets: [
        .target(name: "EatsClone", path: "EatsClone/Core"),
        .testTarget(name: "EatsCloneTests", dependencies: ["EatsClone"], path: "EatsClone/Tests")
    ]
)
