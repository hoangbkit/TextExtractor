import XCTest

@testable import TextExtractor

final class DOCXTextExtractorTests: XCTestCase {
    func testDOCXExtractsParagraphsTablesFootnotesAndEndnotes() throws {
        let url = try FixtureSupport.makeArchiveFile(entries: [
            "[Content_Types].xml": """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
              <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
              <Default Extension="xml" ContentType="application/xml"/>
            </Types>
            """,
            "word/document.xml": """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
              <w:body>
                <w:p><w:r><w:t>Hello DOCX.</w:t></w:r></w:p>
                <w:p><w:r><w:t>Second paragraph</w:t></w:r><w:r><w:tab/></w:r><w:r><w:t>with tab.</w:t></w:r></w:p>
                <w:tbl>
                  <w:tr>
                    <w:tc><w:p><w:r><w:t>Cell A</w:t></w:r></w:p></w:tc>
                    <w:tc><w:p><w:r><w:t>Cell B</w:t></w:r></w:p></w:tc>
                  </w:tr>
                </w:tbl>
              </w:body>
            </w:document>
            """,
            "word/footnotes.xml": """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <w:footnotes xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
              <w:footnote w:id="2"><w:p><w:r><w:t>Footnote text.</w:t></w:r></w:p></w:footnote>
            </w:footnotes>
            """,
            "word/endnotes.xml": """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <w:endnotes xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
              <w:endnote w:id="2"><w:p><w:r><w:t>Endnote text.</w:t></w:r></w:p></w:endnote>
            </w:endnotes>
            """
        ])
        defer { FixtureSupport.removeTemporaryFixture(at: url) }

        let document = try TextExtractor().extract(from: url)

        XCTAssertEqual(document.format, .docx)
        XCTAssertTrue(document.text.contains("Hello DOCX."))
        XCTAssertTrue(document.text.contains("Second paragraph\twith tab."))
        XCTAssertTrue(document.text.contains("Cell A"))
        XCTAssertTrue(document.text.contains("Cell B"))
        XCTAssertTrue(document.text.contains("Footnote text."))
        XCTAssertTrue(document.text.contains("Endnote text."))
    }

    func testDOCXHeadersAndFootersAreOptional() throws {
        let url = try FixtureSupport.makeArchiveFile(entries: [
            "[Content_Types].xml": "<Types></Types>",
            "word/document.xml": """
            <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>Body only.</w:t></w:r></w:p></w:body></w:document>
            """,
            "word/header1.xml": """
            <w:hdr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:p><w:r><w:t>Header text.</w:t></w:r></w:p></w:hdr>
            """
        ])
        defer { FixtureSupport.removeTemporaryFixture(at: url) }

        let defaultDoc = try TextExtractor().extract(from: url)
        XCTAssertFalse(defaultDoc.text.contains("Header text."))

        var options = TextExtractionOptions()
        options.includeDOCXHeadersAndFooters = true
        let withHeaders = try TextExtractor().extract(from: url, options: options)
        XCTAssertTrue(withHeaders.text.contains("Header text."))
    }

    func testMalformedOptionalDOCXPartUsesStableWarningCode() throws {
        let url = try FixtureSupport.makeArchiveFile(entries: [
            "[Content_Types].xml": "<Types></Types>",
            "word/document.xml": """
            <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>Body text.</w:t></w:r></w:p></w:body></w:document>
            """,
            "word/footnotes.xml": "<w:footnotes>"
        ])
        defer { FixtureSupport.removeTemporaryFixture(at: url) }

        let document = try TextExtractor().extract(from: url)

        XCTAssertEqual(document.text, "Body text.")
        XCTAssertEqual(document.warnings.count, 1)
        XCTAssertEqual(document.warnings[0].code, .skippedDOCXFootnotes)
    }
}
