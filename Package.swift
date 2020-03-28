// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ReviewKit",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "ReviewKit",
            targets: ["ReviewKit"]),
    ],
    dependencies: [
        
    ],
    targets: [
        .target(
            name: "ReviewKit",
            dependencies: []),
        .testTarget(
            name: "ReviewKitTests",
            dependencies: ["ReviewKit"]),
    ]
)
