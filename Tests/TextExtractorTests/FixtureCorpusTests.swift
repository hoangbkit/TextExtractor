import XCTest

@testable import TextExtractor

final class FixtureCorpusTests: XCTestCase {
    func testTXTFixtures() throws {
        try FixtureSupport.assertReadableFixture(
            directory: "txt",
            expectedFormat: .plainText,
            expectedShortText: "The sun rose over the tranquil meadow"
        )
    }

    func testMDFixtures() throws {
        try FixtureSupport.assertReadableFixture(
            directory: "md",
            expectedFormat: .markdown,
            expectedShortText: "The Wandering Albatross",
            forbiddenFragments: ["**", "# "]
        )
    }

    func testMarkdownExtensionFixtures() throws {
        try FixtureSupport.assertReadableFixture(
            directory: "markdown",
            expectedFormat: .markdown,
            expectedShortText: "The Northern Lights",
            forbiddenFragments: ["**", "# "]
        )
    }

    func testSRTFixtures() throws {
        try FixtureSupport.assertReadableFixture(
            directory: "srt",
            expectedFormat: .srt,
            expectedShortText: "The sun dipped below the horizon",
            forbiddenFragments: ["-->"]
        )
    }

    func testVTTFixtures() throws {
        try FixtureSupport.assertReadableFixture(
            directory: "vtt",
            expectedFormat: .vtt,
            expectedShortText: "The first cherry blossoms of spring",
            forbiddenFragments: ["WEBVTT", "-->"]
        )
    }

    func testHTMLFixtures() throws {
        try FixtureSupport.assertReadableFixture(
            directory: "html",
            expectedFormat: .html,
            expectedShortText: "The humble bicycle",
            forbiddenFragments: ["<html", "<body", "<p>"]
        )
    }

    func testHTMFixtures() throws {
        try FixtureSupport.assertReadableFixture(
            directory: "htm",
            expectedFormat: .html,
            expectedShortText: "The violin, with its four strings",
            forbiddenFragments: ["<html", "<body", "<p>"]
        )
    }

    #if canImport(AppKit) || canImport(UIKit)
    func testRTFFixtures() throws {
        try FixtureSupport.assertReadableFixture(
            directory: "rtf",
            expectedFormat: .rtf,
            expectedShortText: "The piano sat silently in the corner",
            forbiddenFragments: ["\\rtf1", "\\par"]
        )
    }
    #endif

    func testDOCXFixtures() throws {
        try FixtureSupport.assertReadableFixture(
            directory: "docx",
            expectedFormat: .docx,
            forbiddenFragments: ["<w:", "word/document.xml"]
        )
    }
}
