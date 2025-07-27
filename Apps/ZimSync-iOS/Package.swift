// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ZimSync-iOS",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "ZimSyncKit",
            targets: ["ZimSyncKit"]
        )
    ],
    dependencies: [
        .package(path: "../..") // ZimSyncCore from root
    ],
    targets: [
        .target(
            name: "ZimSyncKit",
            dependencies: [
                .product(name: "ZimSyncCore", package: "zim-sync")
            ]
        )
    ]
)