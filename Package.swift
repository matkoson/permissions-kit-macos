// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MacPermissionKit",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(name: "MacPermissionKit", targets: ["MacPermissionKit"]),
        .executable(name: "matkoson-permissions", targets: ["matkoson-permissions"])
    ],
    targets: [
        .target(
            name: "MacPermissionKit",
            path: "Sources/MacPermissionKit",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
        .executableTarget(
            name: "matkoson-permissions",
            dependencies: ["MacPermissionKit"],
            path: "Sources/matkoson-permissions",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
        .testTarget(
            name: "MacPermissionKitTests",
            dependencies: ["MacPermissionKit"],
            path: "Tests/MacPermissionKitTests",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny")
            ]
        )
    ]
)
