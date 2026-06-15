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
        // Tests run as a plain executable so they work with Command Line Tools
        // only (XCTest/swift-testing require full Xcode). Run: swift run KashTasksTests
        .executableTarget(
            name: "KashTasksTests",
            dependencies: ["KashTasksCore"]
        ),
    ]
)
