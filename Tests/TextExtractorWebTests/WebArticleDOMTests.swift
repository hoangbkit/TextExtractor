import Foundation
import SwiftSoup
import XCTest
@testable import TextExtractorWeb

final class WebArticleDOMTests: XCTestCase {
    func testSemanticTraversalRetainsTypesAndNestedListItemsWithoutDuplicates() throws {
        let html = """
        <article>
          <h1>Story</h1>
          <p>First <strong>important</strong> paragraph.</p>
          <ul>
            <li><p>Parent introduction.</p>
                <div><ul><li>Nested child.</li></ul></div>
            </li>
            <li><p>One sentence.</p><p>Another sentence.</p></li>
          </ul>
          <blockquote><p>A quoted thought.</p></blockquote>
          <pre><code>first line
        second line</code></pre>
          <table><tr><th>Day</th><th>Weather</th></tr>
            <tr><td>Monday</td><td>Cloudy</td></tr></table>
          <figure><figcaption>The notebook.</figcaption></figure>
          <div>Loose text with no paragraph tag.</div>
        </article>
        """
        let document = try SwiftSoup.parseBodyFragment(html)
        let root = try XCTUnwrap(document.body())
        var parser = WebArticleBlockCollector(options: .init())
        try parser.collect(root)

        XCTAssertEqual(parser.blocks.map(\.kind), [
            .heading(level: 1), .paragraph, .listItem, .listItem,
            .listItem, .quote, .code, .table, .caption, .preservedContent
        ])
        XCTAssertEqual(parser.blocks[1].text, "First important paragraph.")
        XCTAssertEqual(parser.blocks[2].text, "Parent introduction.")
        XCTAssertEqual(parser.blocks[3].text, "Nested child.")
        XCTAssertEqual(parser.blocks[4].text, "One sentence. Another sentence.")
        XCTAssertEqual(parser.blocks[5].text, "A quoted thought.")
        XCTAssertEqual(parser.blocks[6].text, "first line\nsecond line")
        XCTAssertEqual(parser.blocks[7].text, "Day\tWeather\nMonday\tCloudy")
        XCTAssertEqual(parser.blocks[8].text, "The notebook.")
        XCTAssertEqual(parser.blocks[9].text, "Loose text with no paragraph tag.")
    }

    func testDepthAndBlockLimitsRejectInsteadOfTruncating() throws {
        let html = """
        <div><section><article><p>A paragraph.</p></article></section></div>
        """
        let document = try SwiftSoup.parseBodyFragment(html)
        let root = try XCTUnwrap(document.body())
        var shallow = WebArticleBlockCollector(options: .init(maxDOMDepth: 1))
        XCTAssertThrowsError(try shallow.collect(root)) {
            XCTAssertEqual($0 as? WebArticleExtractionError, .domTooDeep(maxDepth: 1))
        }
    }

    func testLooseTextAndEqualParagraphOccurrencesStayInSourceOrder() throws {
        let html = """
        <article>
          <div>Intro <em>important</em> content.</div>
          <p>Repeated.</p>
          <p>Repeated.</p>
          <script>mustNeverAppear()</script>
        </article>
        """
        let document = try SwiftSoup.parseBodyFragment(html)
        var parser = WebArticleBlockCollector(options: .init())
        try parser.collect(try XCTUnwrap(document.body()))

        XCTAssertEqual(parser.blocks.map(\.kind), [
            .preservedContent, .paragraph, .paragraph
        ])
        XCTAssertEqual(parser.blocks.map(\.text), [
            "Intro important content.", "Repeated.", "Repeated."
        ])
    }

    func testExplicitBlockLimitRefusesSecondBlock() throws {
        let document = try SwiftSoup.parseBodyFragment("<p>First.</p><p>Second.</p>")
        var parser = WebArticleBlockCollector(options: .init(maxBlocks: 1))
        XCTAssertThrowsError(try parser.collect(try XCTUnwrap(document.body()))) {
            XCTAssertEqual($0 as? WebArticleExtractionError, .tooManyBlocks(maxBlocks: 1))
        }
    }
}
