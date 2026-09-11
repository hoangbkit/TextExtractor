import Foundation
import XCTest

@testable import TextExtractor

final class HTMLTextExtractorTests: XCTestCase {
    func testHTMLExtractionProducesReadableText() throws {
        let html = """
        <!doctype html>
        <html>
          <head><style>.x{}</style><script>bad()</script></head>
          <body><h1>Title</h1><p>Hello <strong>reader</strong> &amp; creator.</p></body>
        </html>
        """
        let document = try TextExtractor().extract(data: Data(html.utf8), fileName: "page.html")
        XCTAssertEqual(document.format, .html)
        XCTAssertTrue(document.text.contains("Title"))
        XCTAssertTrue(document.text.contains("Hello reader & creator."))
        XCTAssertFalse(document.text.contains("bad()"))
    }

    func testHTMLExtractionPreservesSemanticParagraphBoundaries() throws {
        let html = "<h1>Title</h1><p>First paragraph.</p><p>Second paragraph.</p>"
        let document = try TextExtractor().extract(data: Data(html.utf8), fileName: "paragraphs.html")

        XCTAssertEqual(
            document.text,
            "Title\n\nFirst paragraph.\n\nSecond paragraph."
        )
    }

    func testHTMLExtractionKeepsBRAsSingleLineBreak() throws {
        let html = "<p>Line one<br>Line two</p><p>Next paragraph.</p>"
        let document = try TextExtractor().extract(data: Data(html.utf8), fileName: "breaks.html")

        XCTAssertEqual(
            document.text,
            "Line one\nLine two\n\nNext paragraph."
        )
    }

    func testHTMLExtractionHonorsCustomParagraphSeparator() throws {
        let html = "<h2>Heading</h2><p>Body text.</p>"
        var options = TextExtractionOptions()
        options.paragraphSeparator = "\n---\n"

        let document = try TextExtractor().extract(
            data: Data(html.utf8),
            fileName: "custom-separator.html",
            options: options
        )

        XCTAssertEqual(document.text, "Heading\n---\nBody text.")
    }

    func testHTMLExtractionFlattensBlocksWhenParagraphPreservationIsDisabled() throws {
        let html = "<h1>Title</h1><p>First paragraph.</p><p>Second paragraph.</p>"
        var options = TextExtractionOptions()
        options.preserveParagraphs = false

        let document = try TextExtractor().extract(
            data: Data(html.utf8),
            fileName: "flattened.html",
            options: options
        )

        XCTAssertEqual(document.text, "Title First paragraph. Second paragraph.")
    }

    func testBasicHTMLFallbackDirectly() throws {
        let html = "<html><body><p>Hello &amp; goodbye.</p><script>bad()</script></body></html>"
        let text = try BasicHTMLTextExtractor.extractText(from: Data(html.utf8), fileName: "fallback.html", options: TextExtractionOptions())
        XCTAssertEqual(text, "Hello & goodbye.")
    }

    func testBasicHTMLFallbackPreservesSemanticParagraphBoundaries() {
        let html = "<h1>Title</h1><p>First paragraph.</p><p>Second paragraph.</p>"
        let text = BasicHTMLTextExtractor.extractText(
            fromHTMLString: html,
            options: TextExtractionOptions()
        )

        XCTAssertEqual(text, "Title\n\nFirst paragraph.\n\nSecond paragraph.")
    }

    func testFallbackHandlesCommentsQuotedGreaterThanAndTables() {
        let html = """
        <!-- hidden -->
        <div data-value="a > b">Visible</div>
        <table><tr><td>Alpha</td><td>Beta</td></tr></table>
        """
        let text = BasicHTMLTextExtractor.extractText(fromHTMLString: html, options: TextExtractionOptions())
        XCTAssertTrue(text.contains("Visible"))
        XCTAssertTrue(text.contains("Alpha Beta"))
        XCTAssertFalse(text.contains("hidden"))
        XCTAssertFalse(text.contains("data-value"))
    }

    func testFallbackRemovesScriptStyleAndNoscript() {
        let html = "<style>bad1</style><script>bad2</script><noscript>bad3</noscript><main>Good</main>"
        let text = BasicHTMLTextExtractor.extractText(fromHTMLString: html, options: TextExtractionOptions())
        XCTAssertEqual(text, "Good")
    }

    func testEmptyHTMLFailsAtCoordinatorBoundary() {
        XCTAssertThrowsError(try TextExtractor().extract(data: Data(), fileName: "empty.html"))
    }
}
