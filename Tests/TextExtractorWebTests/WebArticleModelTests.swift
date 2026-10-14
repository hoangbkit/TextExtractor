import Foundation
import XCTest
@testable import TextExtractorWeb

final class WebArticleModelTests: XCTestCase {
    private let url = URL(string: "https://example.org/articles/gardens")!

    func testResultRendersFromTypedBlocksWithoutLosingStructure() throws {
        let blocks = [
            try WebArticleBlock(id: "block-000001", kind: .heading(level: 1), text: "A Small Garden"),
            try WebArticleBlock(id: "block-000002", kind: .paragraph, text: "First paragraph."),
            try WebArticleBlock(id: "block-000003", kind: .paragraph, text: "Second paragraph."),
            try WebArticleBlock(id: "block-000004", kind: .code, text: "let a = 1\nlet b = 2")
        ]
        let result = try WebArticleResult(
            title: "  A Small Garden  ",
            sourceURL: url,
            blocks: blocks,
            metadata: ["author": "Sam", "siteName": "Example"]
        )

        XCTAssertEqual(result.title, "A Small Garden")
        XCTAssertEqual(result.blocks.map(\.kind), [
            .heading(level: 1), .paragraph, .paragraph, .code
        ])
        XCTAssertEqual(
            result.text,
            "A Small Garden\n\nFirst paragraph.\n\nSecond paragraph.\n\nlet a = 1\nlet b = 2"
        )
        XCTAssertEqual(result.metadata["author"], "Sam")
    }

    func testRepeatedVisibleTextMustUseSeparateIDs() throws {
        let first = try WebArticleBlock(id: "block-000001", kind: .paragraph, text: "Repeated.")
        let second = try WebArticleBlock(id: "block-000002", kind: .paragraph, text: "Repeated.")
        let result = try WebArticleResult(title: "Repeated", sourceURL: url, blocks: [first, second])

        XCTAssertNotEqual(first.id, second.id)
        XCTAssertEqual(result.blocks.count, 2)
        XCTAssertEqual(result.text, "Repeated.\n\nRepeated.")

        XCTAssertThrowsError(try WebArticleResult(
            title: "Repeated", sourceURL: url, blocks: [first, first]
        )) {
            XCTAssertEqual($0 as? WebArticleModelError, .duplicateBlockIdentifier(first.id))
        }
    }

    func testInvalidModelValuesAreRejected() throws {
        XCTAssertThrowsError(try WebArticleBlock(id: "  ", kind: .paragraph, text: "Hello")) {
            XCTAssertEqual($0 as? WebArticleModelError, .emptyBlockIdentifier)
        }
        XCTAssertThrowsError(try WebArticleBlock(id: "a", kind: .paragraph, text: "  ")) {
            XCTAssertEqual($0 as? WebArticleModelError, .emptyBlockText)
        }
        XCTAssertThrowsError(try WebArticleBlock(id: "a", kind: .heading(level: 7), text: "No")) {
            XCTAssertEqual($0 as? WebArticleModelError, .invalidHeadingLevel(7))
        }
        let block = try WebArticleBlock(id: "a", kind: .paragraph, text: "Text")
        XCTAssertThrowsError(try WebArticleResult(title: " ", sourceURL: url, blocks: [block])) {
            XCTAssertEqual($0 as? WebArticleModelError, .emptyTitle)
        }
        XCTAssertThrowsError(try WebArticleResult(title: "Hi", sourceURL: url, blocks: [])) {
            XCTAssertEqual($0 as? WebArticleModelError, .emptyBlocks)
        }
    }

    func testCodingRoundTripAndDecodedValidation() throws {
        let blocks = [
            try WebArticleBlock(id: "1", kind: .heading(level: 2), text: "Title"),
            try WebArticleBlock(id: "2", kind: .listItem, text: "A point"),
            try WebArticleBlock(id: "3", kind: .preservedContent, text: "Unknown")
        ]
        let original = try WebArticleResult(title: "Title", sourceURL: url, blocks: blocks)
        let encoder = JSONEncoder()
        let bytes = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(WebArticleResult.self, from: bytes)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.text, "Title\n\nA point\n\nUnknown")

        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        var payloadBlocks = try XCTUnwrap(json["blocks"] as? [[String: Any]])
        payloadBlocks[1]["id"] = "1"
        json["blocks"] = payloadBlocks
        let invalid = try JSONSerialization.data(withJSONObject: json)
        XCTAssertThrowsError(try JSONDecoder().decode(WebArticleResult.self, from: invalid)) {
            XCTAssertEqual($0 as? WebArticleModelError, .duplicateBlockIdentifier("1"))
        }
    }

    func testFixtureManifestIsWellFormedAndAllFixturesExist() throws {
        let catalogURL = try XCTUnwrap(Bundle.module.url(forResource: "fixture-cases", withExtension: "json"))
        let cases = try JSONDecoder().decode(
            [ArticleFixtureCase].self,
            from: Data(contentsOf: catalogURL)
        )
        XCTAssertGreaterThanOrEqual(cases.count, 5)
        XCTAssertTrue(cases.contains(where: { !$0.shouldExtract }))
        XCTAssertTrue(cases.contains(where: { $0.shouldExtract && !$0.expectedBlocks.isEmpty }))

        var names = Set<String>()
        for fixture in cases {
            XCTAssertTrue(names.insert(fixture.name).inserted, fixture.name)
            let file = try XCTUnwrap(
                Bundle.module.url(forResource: fixture.name, withExtension: "html"),
                "Missing article fixture: \(fixture.name)"
            )
            let bytes = try Data(contentsOf: file)
            XCTAssertFalse(bytes.isEmpty, fixture.name)
            if fixture.shouldExtract {
                XCTAssertFalse(fixture.expectedTitle.isEmpty, fixture.name)
                XCTAssertFalse(fixture.expectedBlocks.isEmpty, fixture.name)
                XCTAssertTrue(fixture.expectedBlocks.allSatisfy { !$0.kind.isEmpty && !$0.text.isEmpty })
            } else {
                XCTAssertTrue(fixture.expectedBlocks.isEmpty, fixture.name)
            }
        }
    }

    private struct ArticleFixtureCase: Decodable {
        let name: String
        let shouldExtract: Bool
        let expectedTitle: String
        let expectedBlocks: [ExpectedBlock]
    }

    private struct ExpectedBlock: Decodable {
        let kind: String
        let text: String
    }
}
