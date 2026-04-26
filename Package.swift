// swift-tools-version: 5.8
import PackageDescription

let package = Package(
    name: "StayAwakeForAgent",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(
            name: "StayAwakeForAgent",
            targets: ["StayAwakeForAgent"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "StayAwakeForAgent",
            path: "Sources"),
    ]
)
