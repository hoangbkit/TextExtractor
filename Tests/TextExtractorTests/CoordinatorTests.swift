import Foundation
import XCTest

@testable import TextExtractor

final class CoordinatorTests: XCTestCase {
    func testDefaultExtractorReportsAllSupportedFormats() {
        var expected = Set(TextExtractionFormat.allCases)
        #if !os(macOS)
        expected.remove(.doc)
        #endif

        XCTAssertEqual(
            Set(TextExtractor().supportedFormats),
            expected
        )
    }

    func testDefaultExtractorReportsExpectedExtensions() {
        let extensions = TextExtractor().supportedFileExtensions
        let commonExtensions = [
            "txt", "text", "md", "markdown", "srt", "vtt", "webvtt",
            "rtf", "html", "htm", "docx", "odt", "pptx"
        ]

        for ext in commonExtensions {
            XCTAssertTrue(extensions.contains(ext), "Missing supported extension: \(ext)")
        }

        #if os(macOS)
        XCTAssertTrue(extensions.contains("doc"), "Missing supported extension: doc")
        #else
        XCTAssertFalse(extensions.contains("doc"), "Legacy DOC should be macOS-only")
        #endif
    }

    func testUnsupportedExtensionThrowsDomainError() {
        XCTAssertThrowsError(try TextExtractor().extract(data: Data("hello".utf8), fileName: "image.png")) { error in
            guard case TextExtractionError.unsupportedFileType(let fileName) = error else {
                return XCTFail("Expected unsupported file type, got \(error)")
            }
            XCTAssertEqual(fileName, "image.png")
        }
    }

    func testEmptyRecognizedDocumentThrows() {
        XCTAssertThrowsError(try TextExtractor().extract(data: Data(), fileName: "empty.txt")) { error in
            guard case TextExtractionError.emptyDocument = error else {
                return XCTFail("Expected empty document, got \(error)")
            }
        }
    }
}
