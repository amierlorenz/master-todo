// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "TodoKit",
    platforms: [.macOS(.v26), .iOS(.v26)],
    products: [
        .library(name: "TodoKit", targets: ["TodoKit"]),
    ],
    targets: [
        .target(name: "TodoKit"),
        .testTarget(name: "TodoKitTests", dependencies: ["TodoKit"]),
    ]
)
