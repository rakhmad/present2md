// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "present2md",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "present2mdCore", targets: ["present2mdCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.19"),
    ],
    targets: [
        .target(
            name: "present2mdCore",
            dependencies: ["ZIPFoundation"],
            path: "present2md",
            exclude: ["App", "UI"]
        ),
        .testTarget(
            name: "present2mdTests",
            dependencies: ["present2mdCore"],
            path: "present2mdTests",
            resources: [.copy("../Tests/Fixtures")]
        ),
        .testTarget(
            name: "present2mdIntegrationTests",
            dependencies: ["present2mdCore"],
            path: "present2mdIntegrationTests",
            resources: [.copy("../Tests/Fixtures")]
        ),
        .testTarget(
            name: "present2mdPerformanceTests",
            dependencies: ["present2mdCore"],
            path: "present2mdPerformanceTests",
            resources: [.copy("../Tests/PerformanceFixtures")]
        ),
    ]
)
