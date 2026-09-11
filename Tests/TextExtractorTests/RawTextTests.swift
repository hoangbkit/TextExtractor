import Foundation
import XCTest

@testable import TextExtractor

final class RawTextTests: XCTestCase {
    func testExtractedDocumentRawTextDefaultsToNil() {
        let document = ExtractedTextDocument(
            title: "Binary",
            format: .docx,
            text: "Parsed text"
        )

        XCTAssertNil(document.rawText)
    }

    func testPlainTextExposesDecodedSourceBeforeNormalization() throws {
        let raw = "  Hello  \r\nWorld\t\t!  "
        let document = try TextExtractor().extract(
            data: Data(raw.utf8),
            fileName: "sample.txt"
        )

        XCTAssertEqual(document.rawText, raw)
        XCTAssertEqual(document.text, "Hello\nWorld !")
    }

    func testMarkdownExposesOriginalMarkup() throws {
        let raw = "# Heading\n\nA **bold** [link](https://example.com)."
        let document = try TextExtractor().extract(
            data: Data(raw.utf8),
            fileName: "sample.md"
        )

        XCTAssertEqual(document.rawText, raw)
        XCTAssertEqual(document.text, "Heading\n\nA bold link.")
    }

    func testHTMLExposesOriginalMarkup() throws {
        let raw = "<h1>Heading</h1><p>Hello <strong>world</strong>.</p>"
        let document = try TextExtractor().extract(
            data: Data(raw.utf8),
            fileName: "sample.html"
        )

        XCTAssertEqual(document.rawText, raw)
        XCTAssertEqual(document.text, "Heading\n\nHello world.")
    }

    func testSRTExposesOriginalCueSource() throws {
        let raw = "1\n00:00:01,000 --> 00:00:02,000\nHello world.\n"
        let document = try TextExtractor().extract(
            data: Data(raw.utf8),
            fileName: "sample.srt"
        )

        XCTAssertEqual(document.rawText, raw)
        XCTAssertEqual(document.text, "Hello world.")
    }

    func testVTTExposesOriginalCueSource() throws {
        let raw = "WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nHello world.\n"
        let document = try TextExtractor().extract(
            data: Data(raw.utf8),
            fileName: "sample.vtt"
        )

        XCTAssertEqual(document.rawText, raw)
        XCTAssertEqual(document.text, "Hello world.")
    }

#if canImport(AppKit) || canImport(UIKit)
    func testRTFExposesOriginalMarkup() throws {
        let raw = #"{\rtf1\ansi Hello \b world\b0.}"#
        let document = try TextExtractor().extract(
            data: Data(raw.utf8),
            fileName: "sample.rtf"
        )

        XCTAssertEqual(document.rawText, raw)
        XCTAssertTrue(document.text.contains("Hello world."))
    }
#endif
}
