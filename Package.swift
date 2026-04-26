// swift-tools-version: 5.8
import PackageDescription

let package = Package(
    name: "StayAwake",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(
            name: "StayAwake",
            targets: ["StayAwake"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "StayAwake",
            path: "Sources"),
    ]
)
