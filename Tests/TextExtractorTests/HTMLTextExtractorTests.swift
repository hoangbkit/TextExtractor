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

    func testBasicHTMLFallbackDirectly() throws {
        let html = "<html><body><p>Hello &amp; goodbye.</p><script>bad()</script></body></html>"
        let text = try BasicHTMLTextExtractor.extractText(
            from: Data(html.utf8),
            fileName: "fallback.html",
            options: TextExtractionOptions()
        )

        XCTAssertEqual(text, "Hello & goodbye.")
    }

    func testEmptyHTMLFailsAtCoordinatorBoundary() {
        XCTAssertThrowsError(try TextExtractor().extract(data: Data(), fileName: "empty.html"))
    }
}
