// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WedeSDK",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
    ],
    products: [
        .library(name: "WedeSDK", targets: ["WedeSDK"]),
    ],
    targets: [
        .target(name: "WedeSDK", path: "Sources/WedeSDK"),
    ]
)
