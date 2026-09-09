// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TextExtractor",
    platforms: [
        .macOS("15.0"),
        .iOS("26.0")
    ],
    products: [
        .library(name: "TextExtractor", targets: ["TextExtractor"])
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
        .testTarget(
            name: "TextExtractorTests",
            dependencies: [
                "TextExtractor",
                .product(name: "ZIPFoundation", package: "ZIPFoundation")
            ]
        )
    ]
)
