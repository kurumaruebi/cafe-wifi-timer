// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CafeWiFiTimer",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "CafeWiFiTimer",
            path: "Sources/CafeWiFiTimer"
        )
    ]
)
