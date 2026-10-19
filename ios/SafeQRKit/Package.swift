// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SafeQRKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "SafeQRKit", targets: ["SafeQRKit"]),
        .executable(name: "safeqr-inspect", targets: ["SafeQRInspect"]),
    ],
    targets: [
        .target(
            name: "SafeQRKit",
            resources: [
                .copy("Resources/Localizable.xcstrings"),
                .process("Resources/czech-bank-codes.json"),
                .process("Resources/premium-numbers.json"),
                .process("Resources/official-domains.json"),
                .process("Resources/url-shorteners.json"),
                .process("Resources/iso-currencies.json"),
            ]
        ),
        .executableTarget(name: "SafeQRInspect", dependencies: ["SafeQRKit"]),
        .testTarget(
            name: "SafeQRKitTests",
            dependencies: ["SafeQRKit"]
        ),
    ]
)
