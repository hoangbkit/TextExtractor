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

    func testEmptyRTFThrows() {
        XCTAssertThrowsError(try TextExtractor().extract(data: Data(), fileName: "empty.rtf"))
    }
}
#endif
