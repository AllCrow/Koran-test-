// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "QuranCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "QuranCore", targets: ["QuranCore"]),
        .library(name: "QuranData", targets: ["QuranData"]),
        .library(name: "QuranPractice", targets: ["QuranPractice"])
    ],
    targets: [
        .target(name: "QuranCore"),
        .target(name: "QuranData", dependencies: ["QuranCore"]),
        .target(name: "QuranPractice", dependencies: ["QuranCore"], resources: [.copy("Resources/PracticeReferences")]),
        .testTarget(name: "QuranCoreTests", dependencies: ["QuranCore"]),
        .testTarget(name: "QuranContentTests", dependencies: ["QuranCore", "QuranData"]),
        .testTarget(name: "QuranPracticeTests", dependencies: ["QuranCore", "QuranPractice"])
    ]
)
