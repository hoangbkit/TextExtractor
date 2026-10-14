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
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.19"),
        .package(url: "https://github.com/wolfyy970/swift-readability.git", exact: "0.3.3"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", exact: "2.13.6")
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
            dependencies: [
                .product(name: "SwiftReadability", package: "swift-readability"),
                .product(name: "SwiftSoup", package: "SwiftSoup")
            ]
        ),
        .testTarget(
            name: "TextExtractorWebTests",
            dependencies: [
                "TextExtractorWeb",
                "TextExtractor",
                .product(name: "SwiftSoup", package: "SwiftSoup")
            ],
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
