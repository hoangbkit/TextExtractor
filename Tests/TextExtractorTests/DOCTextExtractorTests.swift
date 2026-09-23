import Foundation
import XCTest
#if canImport(AppKit)
import AppKit
#endif

@testable import TextExtractor

#if canImport(AppKit)
final class DOCTextExtractorTests: XCTestCase {
    func testDOCExtractionRoundTripsNativeWordFormat() throws {
        let data = try makeDOCData(
            """
            Legacy Word heading

            First paragraph.

            Second paragraph with café and résumé.
            """
        )

        let document = try TextExtractor().extract(data: data, fileName: "legacy.doc")

        XCTAssertEqual(document.format, .doc)
        XCTAssertTrue(document.text.contains("Legacy Word heading"))
        XCTAssertTrue(document.text.contains("First paragraph."))
        XCTAssertTrue(document.text.contains("Second paragraph with café and résumé."))
        XCTAssertNil(document.rawText)
        XCTAssertEqual(document.metadata["container"], "Microsoft Word Binary")
        XCTAssertEqual(document.metadata["importer"], "NSAttributedString.docFormat")
    }

    func testDOCCanFlattenParagraphs() throws {
        let data = try makeDOCData("First paragraph.\n\nSecond paragraph.")

        var options = TextExtractionOptions()
        options.preserveParagraphs = false

        let document = try TextExtractor().extract(
            data: data,
            fileName: "flattened.doc",
            options: options
        )

        XCTAssertEqual(document.text, "First paragraph. Second paragraph.")
    }

    func testDOCExtractorRecognizesExtensionCaseInsensitively() {
        let extractor = DOCTextExtractor()

        XCTAssertTrue(extractor.canExtract(data: Data(), fileName: "legacy.doc"))
        XCTAssertTrue(extractor.canExtract(data: Data(), fileName: "LEGACY.DOC"))
        XCTAssertFalse(extractor.canExtract(data: Data(), fileName: "legacy.docx"))
    }

    func testMalformedDOCUsesDomainError() {
        let malformed = Data([
            0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1,
            0x00, 0x00, 0x00, 0x00
        ])

        XCTAssertThrowsError(
            try TextExtractor().extract(data: malformed, fileName: "broken.doc")
        ) { error in
            guard case TextExtractionError.invalidDocument(let reason) = error else {
                return XCTFail("Expected invalidDocument, got \(error)")
            }
            XCTAssertTrue(reason.contains("Microsoft Word"))
        }
    }

    private func makeDOCData(_ text: String) throws -> Data {
        let attributed = NSAttributedString(string: text)
        let range = NSRange(location: 0, length: attributed.length)

        return try XCTUnwrap(
            attributed.docFormat(
                from: range,
                documentAttributes: [
                    .documentType: NSAttributedString.DocumentType.docFormat
                ]
            )
        )
    }
}
#endif
