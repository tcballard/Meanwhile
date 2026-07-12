// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "Peripheral",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "Peripheral", targets: ["Peripheral"]),
        .executable(name: "Meanwhile", targets: ["Meanwhile"]),
        .executable(name: "MeanwhileHook", targets: ["MeanwhileHook"])
    ],
    targets: [
        .target(name: "Peripheral"),
        .target(
            name: "MeanwhileCore",
            dependencies: ["Peripheral"]
        ),
        .executableTarget(
            name: "Meanwhile",
            dependencies: ["Peripheral", "MeanwhileCore"]
        ),
        .executableTarget(
            name: "MeanwhileHook",
            dependencies: ["MeanwhileCore"]
        ),
        .testTarget(
            name: "PeripheralTests",
            dependencies: ["Peripheral"]
        ),
        .testTarget(
            name: "MeanwhileCoreTests",
            dependencies: ["MeanwhileCore"]
        )
    ]
)
