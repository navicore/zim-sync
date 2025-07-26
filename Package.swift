// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ZimSync",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "ZimSyncCore",
            targets: ["ZimSyncCore"]
        ),
        .executable(
            name: "zimsync-cli",
            targets: ["ZimSyncCLI"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-log", from: "1.5.0")
    ],
    targets: [
        .target(
            name: "ZimSyncCore",
            dependencies: [
                .product(name: "Logging", package: "swift-log")
            ]
        ),
        .executableTarget(
            name: "ZimSyncCLI",
            dependencies: [
                "ZimSyncCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .testTarget(
            name: "ZimSyncCoreTests",
            dependencies: ["ZimSyncCore"]
        )
    ]
)