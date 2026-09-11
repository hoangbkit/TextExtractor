import XCTest

@testable import TextExtractor

final class StringNormalizerTests: XCTestCase {
    func testPreservesParagraphBoundariesAndCollapsesHorizontalWhitespace() {
        let input = "  First   line  \r\n\r\n\r\n Second\tline  "
        let output = StringNormalizer.normalize(input, options: TextExtractionOptions())
        XCTAssertEqual(output, "First line\n\nSecond line")
    }

    func testNormalizesUnicodeLineAndParagraphSeparators() {
        let input = "First\u{2028}Second\u{2029}Third"
        let output = StringNormalizer.normalize(input, options: TextExtractionOptions())
        XCTAssertEqual(output, "First\nSecond\nThird")
    }

    func testCanFlattenParagraphs() {
        var options = TextExtractionOptions()
        options.preserveParagraphs = false

        let output = StringNormalizer.normalize("First\n\nSecond\tline", options: options)
        XCTAssertEqual(output, "First Second line")
    }

    func testRemovesKnownUnsafeAndInvisibleCharacters() {
        let input = "A\u{0001}B\u{00A0}C\u{200B}D"
        let output = StringNormalizer.normalize(input, options: TextExtractionOptions())
        XCTAssertEqual(output, "AB CD")
    }
}
