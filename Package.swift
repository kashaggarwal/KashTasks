// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KashTasks",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "KashTasksCore"),
        .executableTarget(
            name: "KashTasks",
            dependencies: ["KashTasksCore"]
        ),
        .testTarget(
            name: "KashTasksCoreTests",
            dependencies: ["KashTasksCore"]
        ),
    ]
)
