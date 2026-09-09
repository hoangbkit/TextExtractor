import Foundation
import XCTest
import ZIPFoundation

@testable import TextExtractor

final class DOCXFailureTests: XCTestCase {
    func testMissingDocumentXMLThrowsDomainError() throws {
        let url = try makeDOCX(entries: [
            "[Content_Types].xml": "<Types></Types>"
        ])
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        XCTAssertThrowsError(try TextExtractor().extract(from: url)) { error in
            guard case TextExtractionError.invalidDocument(let reason) = error else {
                return XCTFail("Expected invalidDocument, got \(error)")
            }
            XCTAssertTrue(reason.contains("word/document.xml"))
        }
    }

    private func makeDOCX(entries: [String: String]) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TextExtractorFailureTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("fixture.docx")

        guard let archive = Archive(url: url, accessMode: .create) else {
            throw NSError(
                domain: "TextExtractorTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Could not create ZIP archive."]
            )
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
