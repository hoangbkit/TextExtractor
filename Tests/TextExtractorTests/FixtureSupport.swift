import Foundation
import XCTest
import ZIPFoundation

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

    static func makeArchiveData(
        entries: [String: String],
        fileName: String = "fixture.docx"
    ) throws -> Data {
        let url = try makeArchiveFile(entries: entries, fileName: fileName)
        defer { removeTemporaryFixture(at: url) }
        return try Data(contentsOf: url)
    }

    static func makeArchiveFile(
        entries: [String: String],
        fileName: String = "fixture.docx"
    ) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TextExtractorTestFixture-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let url = directory.appendingPathComponent(fileName)
        do {
            let archive = try Archive(url: url, accessMode: .create)
            for path in entries.keys.sorted() {
                let data = Data((entries[path] ?? "").utf8)
                try archive.addEntry(
                    with: path,
                    type: .file,
                    uncompressedSize: Int64(data.count),
                    compressionMethod: .deflate
                ) { position, size in
                    let start = Int(position)
                    return data.subdata(in: start..<(start + size))
                }
            }
            return url
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
    }

    static func removeTemporaryFixture(at url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    static func textExtractorTemporaryDirectories() throws -> Set<String> {
        let urls = try FileManager.default.contentsOfDirectory(
            at: FileManager.default.temporaryDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        return Set(urls.compactMap { url in
            guard url.lastPathComponent.hasPrefix("TextExtractor-") else { return nil }
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { return nil }
            return url.lastPathComponent
        })
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
