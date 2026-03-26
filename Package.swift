// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "sstats",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "sstats",
            path: "Sources/sstats"
        )
    ]
)
