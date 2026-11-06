// swift-tools-version: 6.0
import PackageDescription

// Platform-neutral logic for the Fit2216 iPhone and Apple Watch apps. Foundation only: no UIKit, SwiftUI or Firebase,
// so the same rules run on both devices and can be tested on any machine.
let package = Package(
    name: "Fit2216Core",
    platforms: [.iOS(.v17), .watchOS(.v10), .macOS(.v13)],
    products: [.library(name: "Fit2216Core", targets: ["Fit2216Core"])],
    targets: [
        .target(name: "Fit2216Core"),
        .testTarget(name: "Fit2216CoreTests", dependencies: ["Fit2216Core"]),
    ],
    swiftLanguageModes: [.v5] // keep Swift 5 rules; the logic does not need Swift 6 strict concurrency
)
