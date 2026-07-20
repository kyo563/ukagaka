// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "UkagakaReproductionProject",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "伺か再現プロジェクト",
            targets: ["UkagakaReproductionProject"]
        )
    ],
    targets: [
        .executableTarget(
            name: "UkagakaReproductionProject",
            resources: [
                .copy("Resources/Characters")
            ],
            linkerSettings: [
                .linkedFramework("Security"),
                .linkedFramework("ServiceManagement")
            ]
        ),
        .testTarget(
            name: "UkagakaReproductionProjectTests",
            dependencies: ["UkagakaReproductionProject"]
        )
    ]
)
