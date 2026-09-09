import XCTest

@testable import TextExtractor

final class DOCXFailureTests: XCTestCase {
    func testMissingDocumentXMLThrowsDomainError() throws {
        let url = try FixtureSupport.makeArchiveFile(entries: [
            "[Content_Types].xml": "<Types></Types>"
        ])
        defer { FixtureSupport.removeTemporaryFixture(at: url) }

        XCTAssertThrowsError(try TextExtractor().extract(from: url)) { error in
            guard case TextExtractionError.invalidDocument(let reason) = error else {
                return XCTFail("Expected invalidDocument, got \(error)")
            }
            XCTAssertTrue(reason.contains("word/document.xml"))
        }
    }
}
