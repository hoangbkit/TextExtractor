import Foundation
import XCTest
import TextExtractor
import TextExtractorWeb

/// Cross-product regression contract: opting into TextExtractorWeb must not
/// replace or alter ordinary TextExtractor HTML dispatch and normalization.
final class WebArticleCompatibilityTests: XCTestCase {
    func testLegacyHTMLExtractionStillUsesItsOwnPlainTextContract() throws {
        let html = "<h1>Title</h1><p>First paragraph.</p><p>Second paragraph.</p>"
        let oldDocument = try TextExtractor().extract(
            data: Data(html.utf8),
            fileName: "sample.html"
        )

        XCTAssertEqual(oldDocument.format, .html)
        XCTAssertEqual(oldDocument.text, "Title\n\nFirst paragraph.\n\nSecond paragraph.")
        XCTAssertTrue(TextExtractor().supportedFileExtensions.contains("html"))
    }

    func testLegacyHTMLCustomOptionsRemainUnchanged() throws {
        let html = "<h2>Heading</h2><p>Body text.</p>"
        var options = TextExtractionOptions()
        options.paragraphSeparator = "\n---\n"

        let document = try TextExtractor().extract(
            data: Data(html.utf8),
            fileName: "sample.htm",
            options: options
        )

        XCTAssertEqual(document.format, .html)
        XCTAssertEqual(document.text, "Heading\n---\nBody text.")
    }

    func testWebResultAndCoreDocumentAreSeparateUnrelatedValues() throws {
        let blocks = [
            try WebArticleBlock(
                id: "block-000001",
                kind: .heading(level: 2),
                text: "Field Notes"
            ),
            try WebArticleBlock(
                id: "block-000002",
                kind: .paragraph,
                text: "A complete and readable paragraph."
            )
        ]
        let url = try XCTUnwrap(URL(string: "https://example.org/notes"))
        let article = try WebArticleResult(
            title: "Field Notes",
            sourceURL: url,
            blocks: blocks
        )

        XCTAssertEqual(article.text, "Field Notes\n\nA complete and readable paragraph.")
        XCTAssertEqual(article.blocks[0].kind, .heading(level: 2))

        let legacy = try TextExtractor().extract(
            data: Data("<p>Unrelated content.</p>".utf8),
            fileName: "legacy.html"
        )
        XCTAssertEqual(legacy.format, .html)
        XCTAssertEqual(legacy.text, "Unrelated content.")
    }
}
