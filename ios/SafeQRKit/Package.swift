// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SafeQRKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "SafeQRKit", targets: ["SafeQRKit"]),
    ],
    targets: [
        .target(
            name: "SafeQRKit",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "SafeQRKitTests",
            dependencies: ["SafeQRKit"]
        ),
    ]
)
