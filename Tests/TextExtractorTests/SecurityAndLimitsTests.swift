import Foundation
import XCTest

@testable import TextExtractor

final class SecurityAndLimitsTests: XCTestCase {
    func testExactlyAtInputLimitSucceeds() throws {
        var options = TextExtractionOptions()
        options.maxInputBytes = 5

        let document = try TextExtractor().extract(
            data: Data("hello".utf8),
            fileName: "limit.txt",
            options: options
        )

        XCTAssertEqual(document.text, "hello")
    }

    func testOneByteOverInputLimitFails() {
        var options = TextExtractionOptions()
        options.maxInputBytes = 5

        XCTAssertThrowsError(
            try TextExtractor().extract(
                data: Data("hello!".utf8),
                fileName: "limit.txt",
                options: options
            )
        ) { error in
            guard case TextExtractionError.fileTooLarge(let actual, let max) = error else {
                return XCTFail("Expected fileTooLarge, got \(error)")
            }
            XCTAssertEqual(actual, 6)
            XCTAssertEqual(max, 5)
        }
    }

    func testDirectoryURLIsRejected() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TextExtractor-Directory-Test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        XCTAssertThrowsError(try TextExtractor().extract(from: directory)) { error in
            guard case TextExtractionError.invalidDocument = error else {
                return XCTFail("Expected invalidDocument, got \(error)")
            }
        }
    }
}
