import Foundation
import XCTest

@testable import TextExtractor

#if canImport(AppKit) || canImport(UIKit)
final class RTFTextExtractorTests: XCTestCase {
    func testRTFExtraction() throws {
        let rtf = #"{\rtf1\ansi\deff0 {\fonttbl {\f0 Helvetica;}}\f0\fs24 Hello \b rich\b0  text.}"#
        let document = try TextExtractor().extract(data: Data(rtf.utf8), fileName: "note.rtf")

        XCTAssertEqual(document.format, .rtf)
        XCTAssertTrue(document.text.contains("Hello rich text."))
    }

    func testEmptyRTFThrowsDomainError() {
        XCTAssertThrowsError(try TextExtractor().extract(data: Data(), fileName: "empty.rtf")) { error in
            guard case TextExtractionError.invalidDocument = error else {
                return XCTFail("Expected invalidDocument, got \(error)")
            }
        }
    }
}
#endif
