// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "present2md",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "present2mdCore", targets: ["present2mdCore"]),
        .executable(name: "present2mdApp", targets: ["present2mdApp"]),
    ],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.19"),
    ],
    targets: [
        .target(
            name: "present2mdCore",
            dependencies: ["ZIPFoundation"],
            path: "present2md"
        ),
        .executableTarget(
            name: "present2mdApp",
            dependencies: ["present2mdCore"],
            path: "present2mdApp"
        ),
        .testTarget(
            name: "present2mdTests",
            dependencies: ["present2mdCore"],
            path: "present2mdTests",
            resources: [.copy("Fixtures")]
        ),
        .testTarget(
            name: "present2mdIntegrationTests",
            dependencies: ["present2mdCore"],
            path: "present2mdIntegrationTests",
            resources: [.copy("Fixtures")]
        ),
        .testTarget(
            name: "present2mdPerformanceTests",
            dependencies: ["present2mdCore"],
            path: "present2mdPerformanceTests",
            resources: [.copy("PerformanceFixtures")]
        ),
    ]
)
