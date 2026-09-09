import Foundation
import XCTest

@testable import TextExtractor

final class Phase5ReliabilityTests: XCTestCase {
    func testInputLimitJustBelowAtAndAboveBoundary() throws {
        let data = Data(String(repeating: "Boundary text ", count: 256).utf8)

        var belowOptions = TextExtractionOptions()
        belowOptions.maxInputBytes = data.count + 1
        XCTAssertNoThrow(try TextExtractor().extract(data: data, fileName: "boundary.txt", options: belowOptions))

        var atOptions = TextExtractionOptions()
        atOptions.maxInputBytes = data.count
        XCTAssertNoThrow(try TextExtractor().extract(data: data, fileName: "boundary.txt", options: atOptions))

        var aboveOptions = TextExtractionOptions()
        aboveOptions.maxInputBytes = data.count - 1
        XCTAssertThrowsError(try TextExtractor().extract(data: data, fileName: "boundary.txt", options: aboveOptions)) { error in
            guard case TextExtractionError.fileTooLarge(let actual, let max) = error else {
                return XCTFail("Expected fileTooLarge, got \(error)")
            }
            XCTAssertEqual(actual, data.count)
            XCTAssertEqual(max, data.count - 1)
        }
    }

    func testLargeMarkdownDocumentExtractsPredictably() throws {
        let paragraphCount = 3_000
        let markdown = (0..<paragraphCount).map { index in
            "## Section \(index)\n\nParagraph **\(index)** with [link](https://example.com/\(index))."
        }.joined(separator: "\n\n")

        let document = try TextExtractor().extract(data: Data(markdown.utf8), fileName: "large.md")

        XCTAssertTrue(document.text.hasPrefix("Section 0"))
        XCTAssertTrue(document.text.contains("Section 2999"))
        XCTAssertFalse(document.text.contains("https://example.com"))
    }

    func testLargeSubtitleFileProducesAllCuesWithoutStateLeakage() throws {
        let cueCount = 1_500
        var srt = ""
        for index in 0..<cueCount {
            let start = String(format: "%02d:%02d:%02d,000", index / 3600, (index / 60) % 60, index % 60)
            let endSecond = index + 1
            let end = String(format: "%02d:%02d:%02d,000", endSecond / 3600, (endSecond / 60) % 60, endSecond % 60)
            srt += "\(index + 1)\n\(start) --> \(end)\nCue number \(index)\n\n"
        }

        let document = try TextExtractor().extract(data: Data(srt.utf8), fileName: "large.srt")

        XCTAssertEqual(document.segments.count, cueCount)
        XCTAssertEqual(document.segments.first?.text, "Cue number 0")
        XCTAssertEqual(document.segments.last?.text, "Cue number 1499")
        XCTAssertEqual(Set(document.segments.map(\.id)).count, cueCount)
    }

    func testLargePermittedDOCXStaysWithinArchiveBudget() throws {
        let repeated = String(repeating: "Large but permitted DOCX content. ", count: 8_000)
        let xml = documentXML(text: repeated)
        let data = try FixtureSupport.makeArchiveData(entries: ["word/document.xml": xml])

        var options = TextExtractionOptions()
        options.maxArchiveEntryBytes = Data(xml.utf8).count + 1_024
        options.maxExpandedArchiveBytes = Data(xml.utf8).count + 1_024

        let document = try TextExtractor().extract(data: data, fileName: "large.docx", options: options)

        XCTAssertTrue(document.text.hasPrefix("Large but permitted DOCX content."))
        XCTAssertEqual(document.metadata["expandedArchiveBytes"], String(Data(xml.utf8).count))
    }

    func testRepeatedExtractionIsDeterministicAndDoesNotLeakTemporaryDirectories() throws {
        let extractor = TextExtractor()
        let markdown = Data("# Repeat\n\nThis is **stable** text.".utf8)
        let docx = try FixtureSupport.makeArchiveData(entries: ["word/document.xml": documentXML(text: "Repeated DOCX")])
        let before = try FixtureSupport.textExtractorTemporaryDirectories()

        var markdownOutputs = Set<String>()
        var docxOutputs = Set<String>()
        for _ in 0..<50 {
            markdownOutputs.insert(try extractor.extract(data: markdown, fileName: "repeat.md").text)
        }
        for _ in 0..<20 {
            docxOutputs.insert(try extractor.extract(data: docx, fileName: "repeat.docx").text)
        }

        let after = try FixtureSupport.textExtractorTemporaryDirectories()
        XCTAssertEqual(markdownOutputs, ["Repeat\n\nThis is stable text."])
        XCTAssertEqual(docxOutputs, ["Repeated DOCX"])
        XCTAssertEqual(after, before)
    }

    func testConcurrentExtractionFromSharedCoordinatorIsDeterministic() async throws {
        let extractor = TextExtractor()
        let data = Data("# Concurrent\n\nShared **coordinator** extraction.".utf8)

        let outputs = try await withThrowingTaskGroup(of: String.self) { group in
            for _ in 0..<32 {
                group.addTask {
                    try extractor.extract(data: data, fileName: "concurrent.md").text
                }
            }

            var results: [String] = []
            for try await output in group {
                results.append(output)
            }
            return results
        }

        XCTAssertEqual(outputs.count, 32)
        XCTAssertEqual(Set(outputs), ["Concurrent\n\nShared coordinator extraction."])
    }

    private func documentXML(text: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:body><w:p><w:r><w:t>\(text)</w:t></w:r></w:p></w:body>
        </w:document>
        """
    }
}
