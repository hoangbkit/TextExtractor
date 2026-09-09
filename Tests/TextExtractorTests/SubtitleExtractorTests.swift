import Foundation
import XCTest

@testable import TextExtractor

final class SubtitleExtractorTests: XCTestCase {
    func testSRTCreatesSegmentsAndReadableText() throws {
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

    func testVTTSkipsHeaderAndParsesCueSettings() throws {
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

    func testSRTWithoutCuesFailsAsEmptyDocument() {
        XCTAssertThrowsError(
            try TextExtractor().extract(data: Data("not a subtitle".utf8), fileName: "broken.srt")
        ) { error in
            guard case TextExtractionError.emptyDocument = error else {
                return XCTFail("Expected empty document, got \(error)")
            }
        }
    }

    func testVTTWithoutCuesFailsAsEmptyDocument() {
        XCTAssertThrowsError(
            try TextExtractor().extract(data: Data("WEBVTT\n\nNOTE no cues".utf8), fileName: "broken.vtt")
        ) { error in
            guard case TextExtractionError.emptyDocument = error else {
                return XCTFail("Expected empty document, got \(error)")
            }
        }
    }
}
