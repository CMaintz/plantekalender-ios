// swift-tools-version: 6.0
import PackageDescription

// Models, API client and view models, kept free of UIKit and SwiftUI so they build and test on
// Linux in CI as well as on macOS. The SwiftUI app in App/ is generated from project.yml.
let package = Package(
    name: "PlantekalenderKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "PlantekalenderKit", targets: ["PlantekalenderKit"])],
    targets: [
        .target(name: "PlantekalenderKit"),
        .testTarget(name: "PlantekalenderKitTests", dependencies: ["PlantekalenderKit"]),
    ]
)
