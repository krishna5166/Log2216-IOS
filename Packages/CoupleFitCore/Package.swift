// swift-tools-version:5.9
import PackageDescription

// Platform-neutral logic for the Couple Fit iPhone and Apple Watch apps. Foundation only: no UIKit, SwiftUI or Firebase,
// so the same rules run on both devices and can be tested on any machine.
let package = Package(
    name: "CoupleFitCore",
    platforms: [.iOS(.v17), .watchOS(.v10), .macOS(.v13)],
    products: [.library(name: "CoupleFitCore", targets: ["CoupleFitCore"])],
    targets: [
        .target(name: "CoupleFitCore"),
        .testTarget(name: "CoupleFitCoreTests", dependencies: ["CoupleFitCore"]),
    ]
)
