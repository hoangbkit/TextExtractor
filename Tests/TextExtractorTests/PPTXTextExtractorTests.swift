import Foundation
import XCTest

@testable import TextExtractor

final class PPTXTextExtractorTests: XCTestCase {
    func testPPTXExtractsSlidesTablesAndSpeakerNotesInPresentationOrder() throws {
        let data = try makePresentationData()

        let document = try TextExtractor().extract(data: data, fileName: "deck.pptx")

        XCTAssertEqual(document.format, .pptx)
        XCTAssertEqual(
            document.text,
            "Second Slide\n\nBody with\nline break\n\nCell A\tCell B\n\nPresenter note for slide two.\n\nFirst Slide\n\nFirst slide body."
        )
        XCTAssertNil(document.rawText)
        XCTAssertEqual(document.metadata["container"], "Office Open XML Presentation")
        XCTAssertEqual(document.metadata["slideCount"], "2")
        XCTAssertEqual(document.segments.map(\.id), ["slide-1", "slide-2"])
        XCTAssertEqual(document.segments.first?.metadata["sourcePath"], "ppt/slides/slide2.xml")
        XCTAssertEqual(document.segments.first?.metadata["speakerNotesIncluded"], "true")
        XCTAssertFalse(document.text.contains("999"))
    }

    func testPPTXCanExcludeSpeakerNotes() throws {
        let data = try makePresentationData()

        var options = TextExtractionOptions()
        options.includePPTXSpeakerNotes = false

        let document = try TextExtractor().extract(
            data: data,
            fileName: "deck.pptx",
            options: options
        )

        XCTAssertFalse(document.text.contains("Presenter note"))
        XCTAssertEqual(document.segments.first?.metadata["speakerNotesIncluded"], "false")
    }

    func testPPTXCanBeDetectedByContentWithoutFileName() throws {
        let data = try makePresentationData()

        let document = try TextExtractor().extract(data: data, fileName: nil)

        XCTAssertEqual(document.format, .pptx)
        XCTAssertTrue(document.text.contains("Second Slide"))
    }

    func testPPTXRejectsMissingSlideRelationship() throws {
        let data = try FixtureSupport.makeArchiveData(
            entries: [
                "[Content_Types].xml": contentTypesXML,
                "ppt/presentation.xml": presentationXML(relationshipIDs: ["rIdMissing"]),
                "ppt/_rels/presentation.xml.rels": relationshipsXML([])
            ],
            fileName: "broken.pptx"
        )

        XCTAssertThrowsError(
            try TextExtractor().extract(data: data, fileName: "broken.pptx")
        ) { error in
            guard case TextExtractionError.invalidDocument(let reason) = error else {
                return XCTFail("Expected invalidDocument, got \(error)")
            }
            XCTAssertTrue(reason.contains("slide relationship"))
        }
    }

    func testPPTXEnforcesArchiveEntryLimit() throws {
        let data = try makePresentationData()
        var options = TextExtractionOptions()
        options.maxArchiveEntryCount = 2

        XCTAssertThrowsError(
            try TextExtractor().extract(
                data: data,
                fileName: "limited.pptx",
                options: options
            )
        ) { error in
            guard case TextExtractionError.invalidDocument(let reason) = error else {
                return XCTFail("Expected invalidDocument, got \(error)")
            }
            XCTAssertTrue(reason.contains("maxArchiveEntryCount"))
        }
    }

    private func makePresentationData() throws -> Data {
        try FixtureSupport.makeArchiveData(
            entries: [
                "[Content_Types].xml": contentTypesXML,
                "ppt/presentation.xml": presentationXML(relationshipIDs: ["rId2", "rId1"]),
                "ppt/_rels/presentation.xml.rels": relationshipsXML([
                    ("rId1", "http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide", "slides/slide1.xml"),
                    ("rId2", "http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide", "slides/slide2.xml")
                ]),
                "ppt/slides/slide1.xml": slideXML(
                    title: "First Slide",
                    body: "First slide body.",
                    includeTable: false,
                    includeLineBreak: false
                ),
                "ppt/slides/slide2.xml": slideXML(
                    title: "Second Slide",
                    body: "Body with",
                    includeTable: true,
                    includeLineBreak: true
                ),
                "ppt/slides/_rels/slide2.xml.rels": relationshipsXML([
                    ("rIdNotes", "http://schemas.openxmlformats.org/officeDocument/2006/relationships/notesSlide", "../notesSlides/notesSlide2.xml")
                ]),
                "ppt/notesSlides/notesSlide2.xml": notesXML
            ],
            fileName: "fixture.pptx"
        )
    }

    private var contentTypesXML: String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
        </Types>
        """
    }

    private func presentationXML(relationshipIDs: [String]) -> String {
        let slides = relationshipIDs.enumerated().map { index, relationshipID in
            "<p:sldId id=\"\(256 + index)\" r:id=\"\(relationshipID)\"/>"
        }.joined()

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <p:presentation
            xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
            xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
          <p:sldIdLst>\(slides)</p:sldIdLst>
        </p:presentation>
        """
    }

    private func relationshipsXML(_ relationships: [(String, String, String)]) -> String {
        let body = relationships.map { id, type, target in
            "<Relationship Id=\"\(id)\" Type=\"\(type)\" Target=\"\(target)\"/>"
        }.joined()

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          \(body)
        </Relationships>
        """
    }

    private func slideXML(
        title: String,
        body: String,
        includeTable: Bool,
        includeLineBreak: Bool
    ) -> String {
        let bodyParagraph = includeLineBreak
            ? "<a:p><a:r><a:t>\(body)</a:t></a:r><a:br/><a:r><a:t>line break</a:t></a:r></a:p>"
            : "<a:p><a:r><a:t>\(body)</a:t></a:r></a:p>"

        let table = includeTable ? """
        <p:graphicFrame>
          <a:graphic>
            <a:graphicData>
              <a:tbl>
                <a:tr>
                  <a:tc><a:txBody><a:p><a:r><a:t>Cell A</a:t></a:r></a:p></a:txBody></a:tc>
                  <a:tc><a:txBody><a:p><a:r><a:t>Cell B</a:t></a:r></a:p></a:txBody></a:tc>
                </a:tr>
              </a:tbl>
            </a:graphicData>
          </a:graphic>
        </p:graphicFrame>
        """ : ""

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <p:sld
            xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
            xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
          <p:cSld>
            <p:spTree>
              <p:sp>
                <p:nvSpPr><p:nvPr><p:ph type="title"/></p:nvPr></p:nvSpPr>
                <p:txBody><a:p><a:r><a:t>\(title)</a:t></a:r></a:p></p:txBody>
              </p:sp>
              <p:sp>
                <p:nvSpPr><p:nvPr><p:ph type="body"/></p:nvPr></p:nvSpPr>
                <p:txBody>\(bodyParagraph)</p:txBody>
              </p:sp>
              \(table)
            </p:spTree>
          </p:cSld>
        </p:sld>
        """
    }

    private var notesXML: String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <p:notes
            xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
            xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
          <p:cSld>
            <p:spTree>
              <p:sp>
                <p:nvSpPr><p:nvPr><p:ph type="body"/></p:nvPr></p:nvSpPr>
                <p:txBody><a:p><a:r><a:t>Presenter note for slide two.</a:t></a:r></a:p></p:txBody>
              </p:sp>
              <p:sp>
                <p:nvSpPr><p:nvPr><p:ph type="sldNum"/></p:nvPr></p:nvSpPr>
                <p:txBody><a:p><a:fld type="slidenum"><a:t>999</a:t></a:fld></a:p></p:txBody>
              </p:sp>
            </p:spTree>
          </p:cSld>
        </p:notes>
        """
    }
}
