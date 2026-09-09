import Foundation
import XCTest

@testable import TextExtractor

final class StringDecoderTests: XCTestCase {
    func testDecodesUTF8() throws {
        XCTAssertEqual(try StringDecoder.decode(Data("Hello".utf8), fileName: "note.txt"), "Hello")
    }

    func testDecodesUTF8BOM() throws {
        var data = Data([0xEF, 0xBB, 0xBF])
        data.append(Data("Hello".utf8))
        XCTAssertEqual(try StringDecoder.decode(data, fileName: "note.txt"), "Hello")
    }

    func testDecodesUTF16LittleEndianBOM() throws {
        var data = Data([0xFF, 0xFE])
        data.append(try XCTUnwrap("Hello".data(using: .utf16LittleEndian)))
        XCTAssertEqual(try StringDecoder.decode(data, fileName: "note.txt"), "Hello")
    }

    func testDecodesUTF16BigEndianBOM() throws {
        var data = Data([0xFE, 0xFF])
        data.append(try XCTUnwrap("Hello".data(using: .utf16BigEndian)))
        XCTAssertEqual(try StringDecoder.decode(data, fileName: "note.txt"), "Hello")
    }

    func testEmptyDataDecodesToEmptyString() throws {
        XCTAssertEqual(try StringDecoder.decode(Data(), fileName: "empty.txt"), "")
    }
}
