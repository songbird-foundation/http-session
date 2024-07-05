// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "http-session",
    platforms: [.iOS(.v16), .tvOS(.v16), .macOS(.v13), .watchOS(.v9), .visionOS(.v1)],
    products: [
        .library(name: "HTTPSession", targets: ["HTTPSession"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-http-types.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "HTTPSession",
            dependencies: [
                .product(name: "HTTPTypes", package: "swift-http-types"),
                .product(name: "HTTPTypesFoundation", package: "swift-http-types"),
            ], 
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency=complete"),
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
        .testTarget(name: "HTTPSessionTests", dependencies: ["HTTPSession"]),
    ]
)
