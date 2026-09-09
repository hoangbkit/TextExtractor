import Foundation
import XCTest

@testable import TextExtractor

final class PlainTextExtractorTests: XCTestCase {
    func testUTF8BOMAndWhitespaceNormalization() throws {
        var data = Data([0xEF, 0xBB, 0xBF])
        data.append(Data("Hello\r\n\r\n   world   ".utf8))

        let document = try TextExtractor().extract(data: data, fileName: "note.txt")

        XCTAssertEqual(document.format, .plainText)
        XCTAssertEqual(document.title, "note")
        XCTAssertEqual(document.text, "Hello\n\nworld")
    }

    func testPlainTextMetadataIsPresent() throws {
        let document = try TextExtractor().extract(data: Data("hello".utf8), fileName: "note.text")
        XCTAssertEqual(document.metadata["encoding"], "auto")
    }

    func testEmptyPlainTextFailsAtCoordinatorBoundary() {
        XCTAssertThrowsError(try TextExtractor().extract(data: Data(), fileName: "empty.txt")) { error in
            guard case TextExtractionError.emptyDocument = error else {
                return XCTFail("Expected empty document, got \(error)")
            }
        }
    }
}
