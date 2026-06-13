import XCTest
import Foundation
@testable import TextExtractor

final class TextExtractorTests: XCTestCase {
    func testPlainTextUTF8BOMAndWhitespaceNormalization() throws {
        var data = Data([0xEF, 0xBB, 0xBF])
        data.append(Data("Hello\r\n\r\n   world   ".utf8))
        let document = try TextExtractor().extract(data: data, fileName: "note.txt")

        XCTAssertEqual(document.format, .plainText)
        XCTAssertEqual(document.title, "note")
        XCTAssertEqual(document.text, "Hello\n\nworld")
    }

    func testMarkdownReadableExtraction() throws {
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

    func testSRTExtractionCreatesSegmentsAndReadableText() throws {
        let srt = """
        1
        00:00:01,000 --> 00:00:03,500
        Hello <i>world</i>.

        2
        00:00:04,000 --> 00:00:06,000
        This is Spokio.
        """

        let document = try TextExtractor().extract(data: Data(srt.utf8), fileName: "captions.srt")

        XCTAssertEqual(document.format, .srt)
        XCTAssertEqual(document.segments.count, 2)
        XCTAssertEqual(document.segments[0].text, "Hello world.")
        XCTAssertEqual(try XCTUnwrap(document.segments[0].startTime), 1.0, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(document.segments[0].endTime), 3.5, accuracy: 0.001)
        XCTAssertTrue(document.text.contains("This is Spokio."))
    }

    func testVTTExtractionSkipsHeaderAndParsesCueSettings() throws {
        let vtt = """
        WEBVTT

        intro
        00:00:00.000 --> 00:00:02.000 align:start position:0%
        Welcome &amp; hello.

        00:00:02.000 --> 00:00:03.250
        Welcome &amp; hello.

        00:00:04.000 --> 00:00:05.000
        Next line.
        """

        let document = try TextExtractor().extract(data: Data(vtt.utf8), fileName: "captions.vtt")

        XCTAssertEqual(document.format, .vtt)
        XCTAssertEqual(document.segments.count, 2, "Consecutive duplicate subtitles should be removed by default.")
        XCTAssertEqual(document.segments[0].id, "intro")
        XCTAssertEqual(document.segments[0].text, "Welcome & hello.")
        XCTAssertEqual(document.segments[1].text, "Next line.")
    }

    func testHTMLExtractionFallbackReadableText() throws {
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

    func testUnsupportedExtensionThrows() throws {
        XCTAssertThrowsError(try TextExtractor().extract(data: Data("hello".utf8), fileName: "image.png")) { error in
            guard case TextExtractionError.unsupportedFileType = error else {
                XCTFail("Expected unsupported file type, got \(error)")
                return
            }
        }
    }
}

#if canImport(AppKit) || canImport(UIKit)
extension TextExtractorTests {
    func testRTFExtraction() throws {
        let rtf = #"{\rtf1\ansi\deff0 {\fonttbl {\f0 Helvetica;}}\f0\fs24 Hello \b rich\b0  text.}"#
        let document = try TextExtractor().extract(data: Data(rtf.utf8), fileName: "note.rtf")

        XCTAssertEqual(document.format, .rtf)
        XCTAssertTrue(document.text.contains("Hello rich text."))
    }
}
#endif
