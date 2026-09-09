import Foundation
import XCTest

@testable import TextExtractor

final class APIContractTests: XCTestCase {
    func testFirstExtensionMatchWins() throws {
        let extractor = TextExtractor(extractors: [
            MarkerExtractor(marker: "first"),
            MarkerExtractor(marker: "second")
        ])
        let document = try extractor.extract(data: Data("ignored".utf8), fileName: "note.txt")
        XCTAssertEqual(document.text, "first")
    }

    func testExtensionMatchPrecedesContentSniffing() throws {
        let extensionExtractor = MarkerExtractor(marker: "extension", canExtractResult: false)
        let sniffingExtractor = SniffingExtractor(marker: "sniffed")
        let extractor = TextExtractor(extractors: [extensionExtractor, sniffingExtractor])
        let document = try extractor.extract(data: Data("sniff".utf8), fileName: "note.txt")
        XCTAssertEqual(document.text, "extension")
    }

    func testCustomExtractorArrayReplacesDefaults() {
        let extractor = TextExtractor(extractors: [MarkerExtractor(marker: "custom", canExtractResult: false)])
        XCTAssertThrowsError(try extractor.extract(data: Data("# heading".utf8), fileName: "note.md")) { error in
            guard case TextExtractionError.unsupportedFileType = error else {
                return XCTFail("Expected unsupportedFileType, got \(error)")
            }
        }
    }

    func testLegacyWarningInitializerRemainsCompatible() {
        let warning = TextExtractionWarning("Legacy warning")
        XCTAssertEqual(warning.code, .unspecified)
        XCTAssertEqual(warning.message, "Legacy warning")
        XCTAssertEqual(warning.description, "Legacy warning")
    }

    func testDefaultOptionsRemainReleaseCompatible() {
        let options = TextExtractionOptions()

        XCTAssertEqual(options.maxInputBytes, 50 * 1024 * 1024)
        XCTAssertTrue(options.normalizeWhitespace)
        XCTAssertTrue(options.preserveParagraphs)
        XCTAssertEqual(options.paragraphSeparator, "\n\n")
        XCTAssertTrue(options.startAccessingSecurityScopedResource)
        XCTAssertEqual(options.markdownMode, .readableText)
        XCTAssertTrue(options.dropMarkdownCodeBlocks)
        XCTAssertTrue(options.removeDuplicateSubtitleLines)
        XCTAssertEqual(options.subtitleCueSeparator, "\n")
        XCTAssertTrue(options.includeDOCXFootnotes)
        XCTAssertTrue(options.includeDOCXEndnotes)
        XCTAssertFalse(options.includeDOCXHeadersAndFooters)
        XCTAssertEqual(options.maxArchiveEntryBytes, 64 * 1024 * 1024)
        XCTAssertEqual(options.maxExpandedArchiveBytes, 128 * 1024 * 1024)
        XCTAssertEqual(options.maxArchiveEntryCount, 2_048)
    }

    func testWarningCodeRawValuesRemainStable() {
        XCTAssertEqual(TextExtractionWarning.Code.unspecified.rawValue, "unspecified")
        XCTAssertEqual(TextExtractionWarning.Code.malformedSubtitleTimestamp.rawValue, "malformedSubtitleTimestamp")
        XCTAssertEqual(TextExtractionWarning.Code.skippedDOCXFootnotes.rawValue, "skippedDOCXFootnotes")
        XCTAssertEqual(TextExtractionWarning.Code.skippedDOCXEndnotes.rawValue, "skippedDOCXEndnotes")
        XCTAssertEqual(TextExtractionWarning.Code.skippedDOCXHeader.rawValue, "skippedDOCXHeader")
        XCTAssertEqual(TextExtractionWarning.Code.skippedDOCXFooter.rawValue, "skippedDOCXFooter")
        XCTAssertEqual(TextExtractionWarning.Code.unsupportedDOCXFeature.rawValue, "unsupportedDOCXFeature")
        XCTAssertEqual(TextExtractionWarning.Code.lossyEncodingFallback.rawValue, "lossyEncodingFallback")
    }
}

private struct MarkerExtractor: TextFormatExtractor {
    let marker: String
    var canExtractResult = true
    var format: TextExtractionFormat { .plainText }
    var supportedFileExtensions: Set<String> { ["txt"] }
    func canExtract(data: Data, fileName: String?) -> Bool { canExtractResult }
    func extract(data: Data, fileName: String?, sourceURL: URL?, options: TextExtractionOptions) throws -> ExtractedTextDocument {
        ExtractedTextDocument(title: "marker", sourceURL: sourceURL, format: .plainText, text: marker)
    }
}

private struct SniffingExtractor: TextFormatExtractor {
    let marker: String
    var format: TextExtractionFormat { .markdown }
    var supportedFileExtensions: Set<String> { ["md"] }
    func canExtract(data: Data, fileName: String?) -> Bool { true }
    func extract(data: Data, fileName: String?, sourceURL: URL?, options: TextExtractionOptions) throws -> ExtractedTextDocument {
        ExtractedTextDocument(title: "sniff", sourceURL: sourceURL, format: .markdown, text: marker)
    }
}
