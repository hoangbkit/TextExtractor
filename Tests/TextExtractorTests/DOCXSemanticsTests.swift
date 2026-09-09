import Foundation
import XCTest

@testable import TextExtractor

final class DOCXSemanticsTests: XCTestCase {
    func testTablesHaveExactTabAndRowSemanticsInBodyOrder() throws {
        let url = try FixtureSupport.makeArchiveFile(entries: [
            "word/document.xml": documentXML("""
            <w:p><w:r><w:t>Before</w:t></w:r></w:p>
            <w:tbl>
              <w:tr>
                <w:tc><w:p><w:r><w:t>A1</w:t></w:r></w:p></w:tc>
                <w:tc><w:p><w:r><w:t>B1</w:t></w:r></w:p></w:tc>
              </w:tr>
              <w:tr>
                <w:tc><w:p><w:r><w:t>A2</w:t></w:r></w:p></w:tc>
                <w:tc><w:p><w:r><w:t>B2</w:t></w:r></w:p></w:tc>
              </w:tr>
            </w:tbl>
            <w:p><w:r><w:t>After</w:t></w:r></w:p>
            """)
        ])
        defer { FixtureSupport.removeTemporaryFixture(at: url) }

        let document = try TextExtractor().extract(from: url)
        XCTAssertEqual(document.text, "Before\n\nA1\tB1\n\nA2\tB2\n\nAfter")
    }

    func testExplicitTabsAndBreaksArePreserved() throws {
        let url = try FixtureSupport.makeArchiveFile(entries: [
            "word/document.xml": documentXML("""
            <w:p>
              <w:r><w:t>Alpha</w:t><w:tab/><w:t>Beta</w:t><w:br/><w:t>Gamma</w:t></w:r>
            </w:p>
            """)
        ])
        defer { FixtureSupport.removeTemporaryFixture(at: url) }

        let document = try TextExtractor().extract(from: url)
        XCTAssertEqual(document.text, "Alpha\tBeta\nGamma")
    }

    func testNestedDeletedTextFieldInstructionsAndVisibleResults() throws {
        let xml = """
        <x:document xmlns:x="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <x:body>
            <x:p>
              <x:r><x:t>Visible</x:t></x:r>
              <x:del>
                <x:r><x:t> deleted-one</x:t></x:r>
                <x:del><x:r><x:t> deleted-two</x:t></x:r></x:del>
                <x:r><x:t> deleted-three</x:t></x:r>
              </x:del>
              <x:ins><x:r><x:t> inserted</x:t></x:r></x:ins>
              <x:r><x:instrText> HYPERLINK hidden-instruction </x:instrText></x:r>
              <x:fldSimple x:instr="DATE"><x:r><x:t> field-result</x:t></x:r></x:fldSimple>
              <x:hyperlink><x:r><x:t> link-text</x:t></x:r></x:hyperlink>
              <x:sdt><x:sdtContent><x:r><x:t> control-text</x:t></x:r></x:sdtContent></x:sdt>
            </x:p>
          </x:body>
        </x:document>
        """
        let url = try FixtureSupport.makeArchiveFile(entries: ["word/document.xml": xml])
        defer { FixtureSupport.removeTemporaryFixture(at: url) }

        let document = try TextExtractor().extract(from: url)
        XCTAssertEqual(document.text, "Visible inserted field-result link-text control-text")
        XCTAssertFalse(document.text.contains("deleted"))
        XCTAssertFalse(document.text.contains("hidden-instruction"))
    }

    func testTextBoxContentIsRetainedWhenReadableTextExists() throws {
        let url = try FixtureSupport.makeArchiveFile(entries: [
            "word/document.xml": documentXML("""
            <w:p>
              <w:r><w:t>Outer</w:t></w:r>
              <w:r><w:drawing><w:txbxContent><w:p><w:r><w:t> box-text</w:t></w:r></w:p></w:txbxContent></w:drawing></w:r>
              <w:r><w:t> end</w:t></w:r>
            </w:p>
            """)
        ])
        defer { FixtureSupport.removeTemporaryFixture(at: url) }

        let document = try TextExtractor().extract(from: url)
        XCTAssertEqual(document.text, "Outer box-text end")
    }

    func testDecimalNestedAndBulletNumbering() throws {
        let numbering = """
        <w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:abstractNum w:abstractNumId="0">
            <w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="decimal"/><w:lvlText w:val="%1."/></w:lvl>
            <w:lvl w:ilvl="1"><w:start w:val="1"/><w:numFmt w:val="decimal"/><w:lvlText w:val="%1.%2."/></w:lvl>
          </w:abstractNum>
          <w:abstractNum w:abstractNumId="1">
            <w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="bullet"/><w:lvlText w:val="•"/></w:lvl>
          </w:abstractNum>
          <w:num w:numId="10"><w:abstractNumId w:val="0"/></w:num>
          <w:num w:numId="11"><w:abstractNumId w:val="1"/></w:num>
        </w:numbering>
        """
        let body = """
        \(numberedParagraph(numID: "10", level: 0, text: "One"))
        \(numberedParagraph(numID: "10", level: 1, text: "Child one"))
        \(numberedParagraph(numID: "10", level: 1, text: "Child two"))
        \(numberedParagraph(numID: "10", level: 0, text: "Two"))
        \(numberedParagraph(numID: "11", level: 0, text: "Bullet"))
        """
        let url = try FixtureSupport.makeArchiveFile(entries: [
            "word/document.xml": documentXML(body),
            "word/numbering.xml": numbering
        ])
        defer { FixtureSupport.removeTemporaryFixture(at: url) }

        let document = try TextExtractor().extract(from: url)
        XCTAssertEqual(document.text, "1. One\n\n1.1. Child one\n\n1.2. Child two\n\n2. Two\n\n• Bullet")
        XCTAssertFalse(document.warnings.contains { $0.code == .unsupportedDOCXFeature })
    }

    func testNumberingStartOverrideIsApplied() throws {
        let numbering = """
        <w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:abstractNum w:abstractNumId="0">
            <w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="decimal"/><w:lvlText w:val="%1."/></w:lvl>
          </w:abstractNum>
          <w:num w:numId="20">
            <w:abstractNumId w:val="0"/>
            <w:lvlOverride w:ilvl="0"><w:startOverride w:val="5"/></w:lvlOverride>
          </w:num>
        </w:numbering>
        """
        let url = try FixtureSupport.makeArchiveFile(entries: [
            "word/document.xml": documentXML(numberedParagraph(numID: "20", level: 0, text: "Starts at five")),
            "word/numbering.xml": numbering
        ])
        defer { FixtureSupport.removeTemporaryFixture(at: url) }

        XCTAssertEqual(try TextExtractor().extract(from: url).text, "5. Starts at five")
    }

    func testMalformedNumberingPreservesCleanParagraphTextAndWarns() throws {
        let url = try FixtureSupport.makeArchiveFile(entries: [
            "word/document.xml": documentXML(numberedParagraph(numID: "10", level: 0, text: "Keep me")),
            "word/numbering.xml": "<w:numbering>"
        ])
        defer { FixtureSupport.removeTemporaryFixture(at: url) }

        let document = try TextExtractor().extract(from: url)
        XCTAssertEqual(document.text, "Keep me")
        XCTAssertEqual(document.warnings.first?.code, .unsupportedDOCXFeature)
    }

    func testFootnoteAndEndnoteSeparatorRecordsAreFilteredInXMLOrder() throws {
        let footnotes = """
        <w:footnotes xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:footnote w:id="-1"><w:p><w:r><w:t>separator</w:t></w:r></w:p></w:footnote>
          <w:footnote w:id="0"><w:p><w:r><w:t>continuation</w:t></w:r></w:p></w:footnote>
          <w:footnote w:id="2"><w:p><w:r><w:t>Footnote two</w:t></w:r></w:p></w:footnote>
          <w:footnote w:id="3"><w:p><w:r><w:t>Footnote three</w:t></w:r></w:p></w:footnote>
        </w:footnotes>
        """
        let endnotes = """
        <w:endnotes xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:endnote w:id="-1"><w:p><w:r><w:t>end-separator</w:t></w:r></w:p></w:endnote>
          <w:endnote w:id="2"><w:p><w:r><w:t>Endnote two</w:t></w:r></w:p></w:endnote>
        </w:endnotes>
        """
        let url = try FixtureSupport.makeArchiveFile(entries: [
            "word/document.xml": documentXML("<w:p><w:r><w:t>Body</w:t></w:r></w:p>"),
            "word/footnotes.xml": footnotes,
            "word/endnotes.xml": endnotes
        ])
        defer { FixtureSupport.removeTemporaryFixture(at: url) }

        let document = try TextExtractor().extract(from: url)
        XCTAssertEqual(document.text, "Body\n\nFootnote two\n\nFootnote three\n\nEndnote two")
        XCTAssertEqual(document.metadata["footnoteParagraphs"], "2")
        XCTAssertEqual(document.metadata["endnoteParagraphs"], "1")
        XCTAssertFalse(document.text.contains("separator"))
        XCTAssertFalse(document.text.contains("continuation"))
    }

    func testHeadersAndFootersArePathOrderedAndDeduplicated() throws {
        let url = try FixtureSupport.makeArchiveFile(entries: [
            "word/document.xml": documentXML("<w:p><w:r><w:t>Body</w:t></w:r></w:p>"),
            "word/header2.xml": headerXML("Header B"),
            "word/header1.xml": headerXML("Header A"),
            "word/footer2.xml": footerXML("Footer B"),
            "word/footer1.xml": footerXML("Header A")
        ])
        defer { FixtureSupport.removeTemporaryFixture(at: url) }

        var options = TextExtractionOptions()
        options.includeDOCXHeadersAndFooters = true
        let document = try TextExtractor().extract(from: url, options: options)

        XCTAssertEqual(document.text, "Body\n\nHeader A\n\nFooter B\n\nHeader B")
        XCTAssertEqual(document.metadata["headerFooterParagraphs"], "3")
    }

    private func numberedParagraph(numID: String, level: Int, text: String) -> String {
        """
        <w:p>
          <w:pPr><w:numPr><w:ilvl w:val="\(level)"/><w:numId w:val="\(numID)"/></w:numPr></w:pPr>
          <w:r><w:t>\(text)</w:t></w:r>
        </w:p>
        """
    }

    private func documentXML(_ body: String) -> String {
        """
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:body>\(body)</w:body>
        </w:document>
        """
    }

    private func headerXML(_ text: String) -> String {
        "<w:hdr xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:p><w:r><w:t>\(text)</w:t></w:r></w:p></w:hdr>"
    }

    private func footerXML(_ text: String) -> String {
        "<w:ftr xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:p><w:r><w:t>\(text)</w:t></w:r></w:p></w:ftr>"
    }
}
