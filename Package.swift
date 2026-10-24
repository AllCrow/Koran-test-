// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "QuranCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "QuranCore", targets: ["QuranCore"])],
    targets: [
        .target(name: "QuranCore"),
        .testTarget(name: "QuranCoreTests", dependencies: ["QuranCore"])
    ]
)
