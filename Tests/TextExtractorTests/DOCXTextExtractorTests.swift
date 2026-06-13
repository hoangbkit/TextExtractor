import XCTest
import Foundation
import ZIPFoundation
@testable import TextExtractor

final class DOCXTextExtractorTests: XCTestCase {
    func testDOCXExtractsParagraphsTablesFootnotesAndEndnotes() throws {
        let url = try makeDOCX(entries: [
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
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let document = try TextExtractor().extract(from: url)

        XCTAssertEqual(document.format, .docx)
        XCTAssertTrue(document.text.contains("Hello DOCX."))
        XCTAssertTrue(document.text.contains("Second paragraph with tab."))
        XCTAssertTrue(document.text.contains("Cell A"))
        XCTAssertTrue(document.text.contains("Cell B"))
        XCTAssertTrue(document.text.contains("Footnote text."))
        XCTAssertTrue(document.text.contains("Endnote text."))
    }

    func testDOCXHeadersAndFootersAreOptional() throws {
        let url = try makeDOCX(entries: [
            "[Content_Types].xml": "<Types></Types>",
            "word/document.xml": """
            <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>Body only.</w:t></w:r></w:p></w:body></w:document>
            """,
            "word/header1.xml": """
            <w:hdr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:p><w:r><w:t>Header text.</w:t></w:r></w:p></w:hdr>
            """
        ])
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let defaultDoc = try TextExtractor().extract(from: url)
        XCTAssertFalse(defaultDoc.text.contains("Header text."))

        var options = TextExtractionOptions()
        options.includeDOCXHeadersAndFooters = true
        let withHeaders = try TextExtractor().extract(from: url, options: options)
        XCTAssertTrue(withHeaders.text.contains("Header text."))
    }

    private func makeDOCX(entries: [String: String]) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("TextExtractorTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("fixture.docx")

        guard let archive = Archive(url: url, accessMode: .create) else {
            throw NSError(domain: "TextExtractorTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create ZIP archive."])
        }

        for (path, string) in entries {
            let data = Data(string.utf8)
            try archive.addEntry(
                with: path,
                type: .file,
                uncompressedSize: UInt32(data.count),
                compressionMethod: .deflate
            ) { position, size in
                let start = Int(position)
                let end = start + size
                return data.subdata(in: start..<end)
            }
        }

        return url
    }
}
