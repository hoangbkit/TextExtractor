import Foundation

enum StringDecoder {
    static func decode(_ data: Data, fileName: String?) throws -> String {
        if data.isEmpty { return "" }

        if let decoded = decodeUsingBOM(data) {
            return decoded.replacingOccurrences(of: "\u{FEFF}", with: "")
        }

        let encodings: [String.Encoding] = [
            .utf8,
            .utf16,
            .utf16LittleEndian,
            .utf16BigEndian,
            .isoLatin1,
            .ascii
        ]

        for encoding in encodings {
            if let string = String(data: data, encoding: encoding) {
                return string.replacingOccurrences(of: "\u{FEFF}", with: "")
            }
        }

        throw TextExtractionError.unreadableTextEncoding(fileName: fileName)
    }

    private static func decodeUsingBOM(_ data: Data) -> String? {
        let bytes = [UInt8](data.prefix(4))

        if bytes.starts(with: [0xEF, 0xBB, 0xBF]) {
            return String(data: data.dropFirst(3), encoding: .utf8)
        }

        if bytes.starts(with: [0xFF, 0xFE]) {
            return String(data: data.dropFirst(2), encoding: .utf16LittleEndian)
        }

        if bytes.starts(with: [0xFE, 0xFF]) {
            return String(data: data.dropFirst(2), encoding: .utf16BigEndian)
        }

        return nil
    }
}
