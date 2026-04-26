// swift-tools-version: 5.8
import PackageDescription

let package = Package(
    name: "AgentDuty",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(
            name: "AgentDuty",
            targets: ["AgentDuty"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "AgentDuty",
            path: "Sources"),
    ]
)
