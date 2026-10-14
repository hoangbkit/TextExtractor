// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TextExtractor",
    platforms: [
        .macOS("15.0"),
        .iOS("26.0")
    ],
    products: [
        .library(name: "TextExtractor", targets: ["TextExtractor"]),
        .library(name: "TextExtractorWeb", targets: ["TextExtractorWeb"])
    ],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.19")
    ],
    targets: [
        .target(
            name: "TextExtractor",
            dependencies: [
                .product(name: "ZIPFoundation", package: "ZIPFoundation")
            ]
        ),
        .target(
            name: "TextExtractorWeb",
            dependencies: []
        ),
        .testTarget(
            name: "TextExtractorWebTests",
            dependencies: ["TextExtractorWeb"],
            resources: [.process("Fixtures")]
        ),
        .testTarget(
            name: "TextExtractorTests",
            dependencies: [
                "TextExtractor",
                .product(name: "ZIPFoundation", package: "ZIPFoundation")
            ]
        )
    ]
)
