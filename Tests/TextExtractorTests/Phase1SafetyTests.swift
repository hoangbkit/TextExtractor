import Foundation
import XCTest
import ZIPFoundation

@testable import TextExtractor

final class Phase1SafetyTests: XCTestCase {
    func testDOCXRejectsEntryAboveExpandedEntryBudget() throws {
        let body = documentXML(text: String(repeating: "Highly compressible text. ", count: 200))
        let data = try makeArchiveData(entries: ["word/document.xml": body])

        var options = TextExtractionOptions()
        options.maxArchiveEntryBytes = 512
        options.maxExpandedArchiveBytes = 16 * 1024

        XCTAssertThrowsError(
            try TextExtractor().extract(data: data, fileName: "oversized.docx", options: options)
        ) { error in
            assertInvalidDocument(error, contains: "maxArchiveEntryBytes")
        }
    }

    func testDOCXRejectsCumulativeExpandedContentAboveBudget() throws {
        let body = documentXML(text: String(repeating: "Body text. ", count: 30))
        let footnotes = footnotesXML(text: String(repeating: "Footnote text. ", count: 30))
        let data = try makeArchiveData(entries: [
            "word/document.xml": body,
            "word/footnotes.xml": footnotes
        ])

        var options = TextExtractionOptions()
        options.maxArchiveEntryBytes = 8 * 1024
        options.maxExpandedArchiveBytes = Data(body.utf8).count + Data(footnotes.utf8).count - 1

        XCTAssertThrowsError(
            try TextExtractor().extract(data: data, fileName: "cumulative.docx", options: options)
        ) { error in
            assertInvalidDocument(error, contains: "maxExpandedArchiveBytes")
        }
    }

    func testDOCXRejectsArchiveWithTooManyEntries() throws {
        var entries = ["word/document.xml": documentXML(text: "Hello")]
        for index in 0..<6 {
            entries["custom/part\(index).xml"] = "<part>\(index)</part>"
        }
        let data = try makeArchiveData(entries: entries)

        var options = TextExtractionOptions()
        options.maxArchiveEntryCount = 3

        XCTAssertThrowsError(
            try TextExtractor().extract(data: data, fileName: "many-parts.docx", options: options)
        ) { error in
            assertInvalidDocument(error, contains: "maxArchiveEntryCount")
        }
    }

    func testGenericZIPIsNotSniffedAsDOCX() throws {
        let data = try makeArchiveData(entries: ["hello.txt": "hello"])
        XCTAssertFalse(DOCXTextExtractor().canExtract(data: data, fileName: nil))
        XCTAssertNil(TextExtractor().extractor(forFileName: nil, data: data))
    }

    func testCorruptDOCXContainerFailsSafely() {
        let corruptZIP = Data([0x50, 0x4B, 0x03, 0x04, 0x00, 0x01, 0x02])

        XCTAssertThrowsError(
            try TextExtractor().extract(data: corruptZIP, fileName: "corrupt.docx")
        ) { error in
            assertInvalidDocument(error, contains: "Could not open DOCX ZIP archive")
        }
    }

    func testDataBasedDOCXDoesNotLeaveTemporaryDirectories() throws {
        let data = try makeArchiveData(entries: ["word/document.xml": documentXML(text: "Hello")])
        let before = try textExtractorTemporaryDirectories()

        for _ in 0..<3 {
            _ = try TextExtractor().extract(data: data, fileName: "memory.docx")
        }

        let after = try textExtractorTemporaryDirectories()
        XCTAssertEqual(after, before)
    }

    func testBinaryTXTIsRejectedInsteadOfDecodedAsLatin1() {
        let pngLikeData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0xFF, 0x10])

        XCTAssertThrowsError(
            try TextExtractor().extract(data: pngLikeData, fileName: "binary.txt")
        ) { error in
            guard case TextExtractionError.unreadableTextEncoding = error else {
                return XCTFail("Expected unreadableTextEncoding, got \(error)")
            }
        }
    }

    func testMalformedUTF16BOMIsRejected() {
        let malformed = Data([0xFF, 0xFE, 0x41])

        XCTAssertThrowsError(try StringDecoder.decode(malformed, fileName: "broken.txt")) { error in
            guard case TextExtractionError.unreadableTextEncoding = error else {
                return XCTFail("Expected unreadableTextEncoding, got \(error)")
            }
        }
    }

    func testMissingFileReturnsDomainError() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("TextExtractor-Missing-\(UUID().uuidString).txt")

        XCTAssertThrowsError(try TextExtractor().extract(from: url)) { error in
            guard case TextExtractionError.invalidDocument = error else {
                return XCTFail("Expected invalidDocument, got \(error)")
            }
        }
    }

    private func makeArchiveData(entries: [String: String]) throws -> Data {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TextExtractorSafetyTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = directory.appendingPathComponent("fixture.zip")
        guard let archive = Archive(url: url, accessMode: .create) else {
            throw NSError(domain: "TextExtractorSafetyTests", code: 1)
        }

        for (path, string) in entries {
            let data = Data(string.utf8)
            try archive.addEntry(
                with: path,
                type: .file,
                uncompressedSize: UInt32(data.count),
                compressionMethod: .deflate
            ) { position, size in
                let start = Int(position)
                return data.subdata(in: start..<(start + size))
            }
        }

        return try Data(contentsOf: url)
    }

    private func documentXML(text: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:body><w:p><w:r><w:t>\(text)</w:t></w:r></w:p></w:body>
        </w:document>
        """
    }

    private func footnotesXML(text: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <w:footnotes xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:footnote w:id="2"><w:p><w:r><w:t>\(text)</w:t></w:r></w:p></w:footnote>
        </w:footnotes>
        """
    }

    private func textExtractorTemporaryDirectories() throws -> Set<String> {
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

    private func assertInvalidDocument(
        _ error: Error,
        contains fragment: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case TextExtractionError.invalidDocument(let reason) = error else {
            return XCTFail("Expected invalidDocument, got \(error)", file: file, line: line)
        }
        XCTAssertTrue(reason.contains(fragment), "Unexpected reason: \(reason)", file: file, line: line)
    }
}
