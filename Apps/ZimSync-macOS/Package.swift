// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ZimSync-macOS",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "ZimSync",
            targets: ["ZimSync"]
        )
    ],
    dependencies: [
        .package(path: "../..") // ZimSyncCore from root
    ],
    targets: [
        .executableTarget(
            name: "ZimSync",
            dependencies: [
                .product(name: "ZimSyncCore", package: "zim-sync")
            ],
            resources: [
                .process("Resources")
            ]
        )
    ]
)