// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MacPermissionKit",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(name: "MacPermissionKit", targets: ["MacPermissionKit"])
    ],
    targets: [
        .target(
            name: "MacPermissionKit",
            path: "Sources/MacPermissionKit",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny")
            ]
        )
    ]
)
