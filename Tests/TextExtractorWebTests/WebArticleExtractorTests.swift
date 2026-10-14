import Foundation
import XCTest
@testable import TextExtractorWeb

final class WebArticleExtractorTests: XCTestCase {
    private let articleURL = URL(string: "https://example.org/articles/journal")!

    private struct Fixture: Decodable {
        let name: String
        let shouldExtract: Bool
        let expectedTitle: String
        let expectedBlocks: [ExpectedBlock]
    }

    private struct ExpectedBlock: Decodable {
        let kind: String
        let text: String
    }

    func testArticleFixturesMatchTypedGoldenOutput() throws {
        for fixture in try loadFixtures() where fixture.shouldExtract {
            let result = try WebArticleExtractor().extract(
                html: try loadHTML(named: fixture.name),
                sourceURL: articleURL
            )
            XCTAssertEqual(result.title, fixture.expectedTitle, fixture.name)
            XCTAssertEqual(result.blocks.map { Self.kindName($0.kind) },
                           fixture.expectedBlocks.map(\.kind), fixture.name)
            XCTAssertEqual(result.blocks.map(\.text),
                           fixture.expectedBlocks.map(\.text), fixture.name)
            XCTAssertEqual(result.text,
                           fixture.expectedBlocks.map(\.text).joined(separator: "\n\n"),
                           fixture.name)
            XCTAssertEqual(Set(result.blocks.map(\.id)).count, result.blocks.count,
                           fixture.name)
            XCTAssertTrue(result.blocks.enumerated().allSatisfy {
                $0.element.id == String(format: "block-%06d", $0.offset + 1)
            }, fixture.name)
        }
    }

    func testNonArticleFixturesDoNotReturnSiteNavigation() throws {
        for fixture in try loadFixtures() where !fixture.shouldExtract {
            XCTAssertThrowsError(try WebArticleExtractor().extract(
                html: try loadHTML(named: fixture.name),
                sourceURL: articleURL
            ), fixture.name) { error in
                XCTAssertEqual(error as? WebArticleExtractionError,
                               .unreadableArticle, fixture.name)
            }
        }
    }

    func testExtractionIsDeterministicAndPreservesMetadata() throws {
        let html = try loadHTML(named: "article-basic")
        let first = try WebArticleExtractor().extract(html: html, sourceURL: articleURL)
        let second = try WebArticleExtractor().extract(html: html, sourceURL: articleURL)
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.metadata["author"], "Avery Lane")
        XCTAssertEqual(first.metadata["siteName"], "Meadow Notes")
        XCTAssertEqual(first.metadata["publishedTime"], "2026-04-20T10:00:00Z")
    }

    func testURLAndByteLimitsAreCheckedBeforeParsing() throws {
        let html = Data("<html><body>Hi</body></html>".utf8)
        XCTAssertThrowsError(try WebArticleExtractor().extract(
            html: html,
            sourceURL: URL(fileURLWithPath: "/tmp/content.html")
        )) {
            XCTAssertEqual($0 as? WebArticleExtractionError, .invalidSourceURL)
        }
        XCTAssertThrowsError(try WebArticleExtractor().extract(
            html: html,
            sourceURL: articleURL,
            options: .init(maxInputBytes: html.count - 1)
        )) {
            XCTAssertEqual($0 as? WebArticleExtractionError,
                           .inputTooLarge(actualBytes: html.count,
                                          maxBytes: html.count - 1))
        }
        XCTAssertThrowsError(try WebArticleExtractor().extract(
            html: Data([0x00, 0x00, 0x00]),
            sourceURL: articleURL
        )) {
            XCTAssertEqual($0 as? WebArticleExtractionError, .unreadableEncoding)
        }
    }

    func testBlockLimitCannotSilentlyDiscardMeaningfulText() throws {
        let html = try loadHTML(named: "article-basic")
        XCTAssertThrowsError(try WebArticleExtractor().extract(
            html: html, sourceURL: articleURL,
            options: .init(maxBlocks: 1)
        )) { error in
            XCTAssertEqual(error as? WebArticleExtractionError,
                           .tooManyBlocks(maxBlocks: 1))
        }
    }

    func testCancellationPropagates() async throws {
        let html = try loadHTML(named: "article-basic")
        let url = articleURL
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try WebArticleExtractor().extract(html: html, sourceURL: url)
        }
        do {
            _ = try await task.value
            XCTFail("Cancelled extraction unexpectedly succeeded")
        } catch is CancellationError {
            // Expected: no conversion into unreadableArticle.
        }
    }

    private func loadFixtures() throws -> [Fixture] {
        let url = try XCTUnwrap(Bundle.module.url(
            forResource: "fixture-cases", withExtension: "json"
        ))
        return try JSONDecoder().decode([Fixture].self, from: Data(contentsOf: url))
    }

    private func loadHTML(named name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "html"))
        return try Data(contentsOf: url)
    }

    private static func kindName(_ kind: WebArticleBlockKind) -> String {
        switch kind {
        case .paragraph: return "paragraph"
        case .heading(let level): return "heading:\(level)"
        case .listItem: return "listItem"
        case .quote: return "quote"
        case .code: return "code"
        case .table: return "table"
        case .caption: return "caption"
        case .preservedContent: return "preservedContent"
        }
    }
}
