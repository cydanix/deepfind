// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "DeepFind",
    platforms: [.macOS(.v14)],
    products: [
        .executable(
            name: "DeepFind",
            targets: ["DeepFind"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/ml-explore/mlx-swift-examples.git", branch: "main"),
        .package(url: "https://github.com/ml-explore/mlx-swift", exact: "0.21.2"),
    ],
    targets: [
        .executableTarget(
            name: "DeepFind",
            dependencies: [
                .product(name: "MLXLLM", package: "mlx-swift-examples"),
                .product(name: "MLXLMCommon", package: "mlx-swift-examples"),
                .product(name: "MLX", package: "mlx-swift"),
            ],
            path: "Sources",
            linkerSettings: [
                .linkedFramework("SwiftUI"),
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation")
            ]
        ),
        .testTarget(
            name: "DeepFindTests",
            dependencies: ["DeepFind"],
            path: "Tests"
        )
    ],
    swiftLanguageVersions: [.v5]
)
