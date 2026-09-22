import Foundation
import XCTest

@testable import TextExtractor

final class ODTTextExtractorTests: XCTestCase {
    func testODTExtractsHeadingsParagraphsListsAndTablesInReadingOrder() throws {
        let url = try makeODT(contentXML: """
        <?xml version="1.0" encoding="UTF-8"?>
        <office:document-content
            xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0"
            xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0"
            xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0">
          <office:body>
            <office:text>
              <text:h text:outline-level="1">ODT Heading</text:h>
              <text:p>First <text:span>paragraph</text:span>.</text:p>
              <text:list>
                <text:list-item><text:p>First item</text:p></text:list-item>
                <text:list-item>
                  <text:p>Second<text:s text:c="2"/>item</text:p>
                  <text:list>
                    <text:list-item><text:p>Nested item</text:p></text:list-item>
                  </text:list>
                </text:list-item>
              </text:list>
              <table:table>
                <table:table-row>
                  <table:table-cell><text:p>Cell A</text:p></table:table-cell>
                  <table:table-cell><text:p>Cell B</text:p></table:table-cell>
                </table:table-row>
              </table:table>
              <text:p>After table<text:tab/>tab<text:line-break/>line</text:p>
            </office:text>
          </office:body>
        </office:document-content>
        """)
        defer { FixtureSupport.removeTemporaryFixture(at: url) }

        let document = try TextExtractor().extract(from: url)

        XCTAssertEqual(document.format, .odt)
        XCTAssertEqual(
            document.text,
            "ODT Heading\n\nFirst paragraph.\n\n• First item\n\n• Second item\n\n• Nested item\n\nCell A\tCell B\n\nAfter table\ttab\nline"
        )
        XCTAssertNil(document.rawText)
        XCTAssertEqual(document.metadata["container"], "OpenDocument")
        XCTAssertEqual(document.metadata["mimeType"], "application/vnd.oasis.opendocument.text")
    }

    func testODTCanBeDetectedByContentWithoutFileName() throws {
        let url = try makeODT(contentXML: minimalContentXML(text: "Detected ODT"))
        defer { FixtureSupport.removeTemporaryFixture(at: url) }
        let data = try Data(contentsOf: url)

        let document = try TextExtractor().extract(data: data, fileName: nil)

        XCTAssertEqual(document.format, .odt)
        XCTAssertEqual(document.text, "Detected ODT")
    }

    func testODTRejectsWrongMimetype() throws {
        let url = try FixtureSupport.makeArchiveFile(
            entries: [
                "mimetype": "application/zip",
                "content.xml": minimalContentXML(text: "Wrong type")
            ],
            fileName: "wrong.odt"
        )
        defer { FixtureSupport.removeTemporaryFixture(at: url) }

        XCTAssertThrowsError(try TextExtractor().extract(from: url)) { error in
            guard case TextExtractionError.invalidDocument(let reason) = error else {
                return XCTFail("Expected invalidDocument, got \(error)")
            }
            XCTAssertTrue(reason.contains("mimetype"))
        }
    }

    func testODTRejectsMalformedContentXML() throws {
        let url = try makeODT(contentXML: "<office:document-content><text:p>broken")
        defer { FixtureSupport.removeTemporaryFixture(at: url) }

        XCTAssertThrowsError(try TextExtractor().extract(from: url)) { error in
            guard case TextExtractionError.invalidDocument = error else {
                return XCTFail("Expected invalidDocument, got \(error)")
            }
        }
    }

    func testODTEnforcesArchiveEntryLimit() throws {
        let url = try makeODT(contentXML: minimalContentXML(text: "Limited"))
        defer { FixtureSupport.removeTemporaryFixture(at: url) }

        var options = TextExtractionOptions()
        options.maxArchiveEntryCount = 1

        XCTAssertThrowsError(try TextExtractor().extract(from: url, options: options)) { error in
            guard case TextExtractionError.invalidDocument(let reason) = error else {
                return XCTFail("Expected invalidDocument, got \(error)")
            }
            XCTAssertTrue(reason.contains("maxArchiveEntryCount"))
        }
    }

    func testODTEnforcesArchiveEntrySizeLimit() throws {
        let url = try makeODT(contentXML: minimalContentXML(text: String(repeating: "A", count: 1_000)))
        defer { FixtureSupport.removeTemporaryFixture(at: url) }

        var options = TextExtractionOptions()
        options.maxArchiveEntryBytes = 128

        XCTAssertThrowsError(try TextExtractor().extract(from: url, options: options)) { error in
            guard case TextExtractionError.invalidDocument(let reason) = error else {
                return XCTFail("Expected invalidDocument, got \(error)")
            }
            XCTAssertTrue(reason.contains("maxArchiveEntryBytes"))
        }
    }

    private func makeODT(contentXML: String) throws -> URL {
        try FixtureSupport.makeArchiveFile(
            entries: [
                "mimetype": "application/vnd.oasis.opendocument.text",
                "content.xml": contentXML
            ],
            fileName: "fixture.odt"
        )
    }

    private func minimalContentXML(text: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <office:document-content
            xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0"
            xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0">
          <office:body>
            <office:text>
              <text:p>\(text)</text:p>
            </office:text>
          </office:body>
        </office:document-content>
        """
    }
}
