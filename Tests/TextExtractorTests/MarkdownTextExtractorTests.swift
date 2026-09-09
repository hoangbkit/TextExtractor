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

    func testSetextTasksReferencesAutolinksAndEscapes() throws {
        let markdown = """
        Setext title
        ============

        - [x] Finished task
        - [ ] Open task

        Read [the guide][guide].
        [guide]: https://example.com/guide "Guide"

        <https://example.com/raw>
        <mailto:hello@example.com>

        \*literal stars\*
        """
        let document = try TextExtractor().extract(data: Data(markdown.utf8), fileName: "cases.md")
        XCTAssertTrue(document.text.contains("Setext title"))
        XCTAssertTrue(document.text.contains("Finished task"))
        XCTAssertTrue(document.text.contains("Open task"))
        XCTAssertTrue(document.text.contains("Read the guide."))
        XCTAssertTrue(document.text.contains("hello@example.com"))
        XCTAssertTrue(document.text.contains("*literal stars*"))
        XCTAssertFalse(document.text.contains("example.com/guide"))
        XCTAssertFalse(document.text.contains("https://example.com/raw"))
    }

    func testCustomFenceAndIndentedCodeAreDropped() throws {
        let markdown = """
        Before

        ````swift
        print("four ticks")
        ````

            indentedCode()

        After
        """
        let document = try TextExtractor().extract(data: Data(markdown.utf8), fileName: "code.md")
        XCTAssertEqual(document.text, "Before\n\nAfter")
    }

    func testNestedBlockquoteAndTableBecomeReadableText() throws {
        let markdown = """
        >> Nested quote

        | Name | Value |
        | --- | --- |
        | Alpha | Beta |
        """
        let document = try TextExtractor().extract(data: Data(markdown.utf8), fileName: "table.md")
        XCTAssertTrue(document.text.contains("Nested quote"))
        XCTAssertTrue(document.text.contains("Name   Value"))
        XCTAssertTrue(document.text.contains("Alpha   Beta"))
        XCTAssertFalse(document.text.contains("---"))
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
            guard case TextExtractionError.emptyDocument = error else { return XCTFail("Expected empty document, got \(error)") }
        }
    }
}
