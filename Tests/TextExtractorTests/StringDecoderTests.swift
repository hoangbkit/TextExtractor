import Foundation
import XCTest

@testable import TextExtractor

final class StringDecoderTests: XCTestCase {
    func testDecodesUTF8() throws {
        let result = try StringDecoder.decodeWithEncoding(Data("Hello".utf8), fileName: "note.txt")
        XCTAssertEqual(result.string, "Hello")
        XCTAssertEqual(result.encodingName, "utf-8")
        XCTAssertFalse(result.usedLegacyFallback)
    }

    func testDecodesUTF8BOM() throws {
        var data = Data([0xEF, 0xBB, 0xBF])
        data.append(Data("Hello".utf8))
        let result = try StringDecoder.decodeWithEncoding(data, fileName: "note.txt")
        XCTAssertEqual(result.string, "Hello")
        XCTAssertEqual(result.encodingName, "utf-8-bom")
    }

    func testDecodesUTF16LittleEndianBOM() throws {
        var data = Data([0xFF, 0xFE])
        data.append(try XCTUnwrap("Hello".data(using: .utf16LittleEndian)))
        let result = try StringDecoder.decodeWithEncoding(data, fileName: "note.txt")
        XCTAssertEqual(result.string, "Hello")
        XCTAssertEqual(result.encodingName, "utf-16le-bom")
    }

    func testDecodesUTF16BigEndianBOM() throws {
        var data = Data([0xFE, 0xFF])
        data.append(try XCTUnwrap("Hello".data(using: .utf16BigEndian)))
        let result = try StringDecoder.decodeWithEncoding(data, fileName: "note.txt")
        XCTAssertEqual(result.string, "Hello")
        XCTAssertEqual(result.encodingName, "utf-16be-bom")
    }

    func testInfersUTF16LittleEndianWithoutBOM() throws {
        let data = try XCTUnwrap("Hello world".data(using: .utf16LittleEndian))
        let result = try StringDecoder.decodeWithEncoding(data, fileName: "note.txt")
        XCTAssertEqual(result.string, "Hello world")
        XCTAssertEqual(result.encodingName, "utf-16le-inferred")
        XCTAssertFalse(result.usedLegacyFallback)
    }

    func testInfersUTF16BigEndianWithoutBOM() throws {
        let data = try XCTUnwrap("Hello world".data(using: .utf16BigEndian))
        let result = try StringDecoder.decodeWithEncoding(data, fileName: "note.txt")
        XCTAssertEqual(result.string, "Hello world")
        XCTAssertEqual(result.encodingName, "utf-16be-inferred")
        XCTAssertFalse(result.usedLegacyFallback)
    }

    func testEmptyDataDecodesToEmptyString() throws {
        let result = try StringDecoder.decodeWithEncoding(Data(), fileName: "empty.txt")
        XCTAssertEqual(result.string, "")
        XCTAssertEqual(result.encodingName, "empty")
    }
}
