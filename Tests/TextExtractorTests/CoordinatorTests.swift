import Foundation
import XCTest

@testable import TextExtractor

final class CoordinatorTests: XCTestCase {
    func testDefaultExtractorReportsAllSupportedFormats() {
        XCTAssertEqual(
            Set(TextExtractor().supportedFormats),
            Set(TextExtractionFormat.allCases)
        )
    }

    func testDefaultExtractorReportsExpectedExtensions() {
        let extensions = TextExtractor().supportedFileExtensions
        for ext in ["txt", "text", "md", "markdown", "srt", "vtt", "webvtt", "rtf", "html", "htm", "docx"] {
            XCTAssertTrue(extensions.contains(ext), "Missing supported extension: \(ext)")
        }
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
