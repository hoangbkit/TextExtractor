import Foundation
import XCTest

@testable import TextExtractor

enum FixtureSupport {
    static var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // TextExtractorTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // repository root
    }

    static var fixturesRoot: URL {
        repositoryRoot.appendingPathComponent("Fixtures", isDirectory: true)
    }

    static func fixtureURL(directory: String, name: String) -> URL {
        fixturesRoot
            .appendingPathComponent(directory, isDirectory: true)
            .appendingPathComponent(name, isDirectory: false)
    }

    static func fixtureURLs(directory: String) throws -> [URL] {
        let url = fixturesRoot.appendingPathComponent(directory, isDirectory: true)
        return try FileManager.default
            .contentsOfDirectory(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
            .filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    static func assertReadableFixture(
        directory: String,
        expectedFormat: TextExtractionFormat,
        expectedShortText: String? = nil,
        forbiddenFragments: [String] = [],
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let urls = try fixtureURLs(directory: directory)
        XCTAssertEqual(urls.count, 3, "Expected short/medium/long fixtures in \(directory)", file: file, line: line)

        for url in urls {
            let document = try TextExtractor().extract(from: url)
            XCTAssertEqual(document.format, expectedFormat, "Unexpected format for \(url.lastPathComponent)", file: file, line: line)
            XCTAssertFalse(
                document.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                "Fixture produced empty output: \(url.lastPathComponent)",
                file: file,
                line: line
            )

            for fragment in forbiddenFragments {
                XCTAssertFalse(
                    document.text.localizedCaseInsensitiveContains(fragment),
                    "Fixture output still contains parser/container markup '\(fragment)': \(url.lastPathComponent)",
                    file: file,
                    line: line
                )
            }

            if url.lastPathComponent.hasPrefix("short."), let expectedShortText {
                XCTAssertTrue(
                    document.text.localizedCaseInsensitiveContains(expectedShortText),
                    "Short fixture lost representative text '\(expectedShortText)': \(url.lastPathComponent)",
                    file: file,
                    line: line
                )
            }
        }
    }
}
