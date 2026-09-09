import Foundation
import XCTest

@testable import TextExtractor

final class MarkdownTextExtractorTests: XCTestCase {
    func testReadableExtractionRemovesCommonMarkup() throws {
        let markdown = """
        ---
        title: Demo
        ---
        # Heading

        This is **important** and [linked](https://example.com).

        - First item
        - Second item

        ```swift
        print("not for narration")
        ```
        """

        let document = try TextExtractor().extract(data: Data(markdown.utf8), fileName: "article.md")

        XCTAssertEqual(document.format, .markdown)
        XCTAssertTrue(document.text.contains("Heading"))
        XCTAssertTrue(document.text.contains("This is important and linked."))
        XCTAssertTrue(document.text.contains("First item"))
        XCTAssertFalse(document.text.contains("print("))
        XCTAssertFalse(document.text.contains("https://example.com"))
    }

    func testRawModePreservesMarkdown() throws {
        var options = TextExtractionOptions()
        options.markdownMode = .raw

        let document = try TextExtractor().extract(
            data: Data("# Heading\n\n**bold**".utf8),
            fileName: "article.markdown",
            options: options
        )

        XCTAssertTrue(document.text.contains("# Heading"))
        XCTAssertTrue(document.text.contains("**bold**"))
    }

    func testEmptyMarkdownFailsAtCoordinatorBoundary() {
        XCTAssertThrowsError(try TextExtractor().extract(data: Data(), fileName: "empty.md")) { error in
            guard case TextExtractionError.emptyDocument = error else {
                return XCTFail("Expected empty document, got \(error)")
            }
        }
    }
}
