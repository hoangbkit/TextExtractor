import Foundation

enum StringDecoder {
    static func decode(_ data: Data, fileName: String?) throws -> String {
        if data.isEmpty { return "" }

        if hasRecognizedBOM(data) {
            guard let decoded = decodeUsingBOM(data) else {
                throw TextExtractionError.unreadableTextEncoding(fileName: fileName)
            }
            return decoded.replacingOccurrences(of: "\u{FEFF}", with: "")
        }

        if let string = String(data: data, encoding: .utf8) {
            return string
        }

        if let string = decodeLikelyUTF16WithoutBOM(data) {
            return string.replacingOccurrences(of: "\u{FEFF}", with: "")
        }

        guard !isLikelyBinary(data) else {
            throw TextExtractionError.unreadableTextEncoding(fileName: fileName)
        }

        let legacyEncodings: [String.Encoding] = [
            .windowsCP1252,
            .isoLatin1
        ]

        for encoding in legacyEncodings {
            if let string = String(data: data, encoding: encoding) {
                return string.replacingOccurrences(of: "\u{FEFF}", with: "")
            }
        }

        throw TextExtractionError.unreadableTextEncoding(fileName: fileName)
    }

    private static func hasRecognizedBOM(_ data: Data) -> Bool {
        let bytes = [UInt8](data.prefix(3))
        return bytes.starts(with: [0xEF, 0xBB, 0xBF])
            || bytes.starts(with: [0xFF, 0xFE])
            || bytes.starts(with: [0xFE, 0xFF])
    }

    private static func decodeUsingBOM(_ data: Data) -> String? {
        let bytes = [UInt8](data.prefix(4))

        if bytes.starts(with: [0xEF, 0xBB, 0xBF]) {
            return String(data: data.dropFirst(3), encoding: .utf8)
        }

        if bytes.starts(with: [0xFF, 0xFE]) {
            guard (data.count - 2).isMultiple(of: 2) else { return nil }
            return String(data: data.dropFirst(2), encoding: .utf16LittleEndian)
        }

        if bytes.starts(with: [0xFE, 0xFF]) {
            guard (data.count - 2).isMultiple(of: 2) else { return nil }
            return String(data: data.dropFirst(2), encoding: .utf16BigEndian)
        }

        return nil
    }

    private static func decodeLikelyUTF16WithoutBOM(_ data: Data) -> String? {
        guard data.count >= 4, data.count.isMultiple(of: 2) else { return nil }

        let bytes = [UInt8](data.prefix(2_048))
        let pairCount = bytes.count / 2
        guard pairCount >= 2 else { return nil }

        var evenZeroCount = 0
        var oddZeroCount = 0
        for pairIndex in 0..<pairCount {
            if bytes[pairIndex * 2] == 0 { evenZeroCount += 1 }
            if bytes[pairIndex * 2 + 1] == 0 { oddZeroCount += 1 }
        }

        let strongZeroThreshold = max(2, pairCount / 3)
        let weakZeroThreshold = max(1, pairCount / 20)

        if oddZeroCount >= strongZeroThreshold, evenZeroCount <= weakZeroThreshold {
            return String(data: data, encoding: .utf16LittleEndian)
        }

        if evenZeroCount >= strongZeroThreshold, oddZeroCount <= weakZeroThreshold {
            return String(data: data, encoding: .utf16BigEndian)
        }

        return nil
    }

    private static func isLikelyBinary(_ data: Data) -> Bool {
        let sample = [UInt8](data.prefix(4_096))
        guard !sample.isEmpty else { return false }

        let knownBinarySignatures: [[UInt8]] = [
            [0x89, 0x50, 0x4E, 0x47],
            [0xFF, 0xD8, 0xFF],
            [0x47, 0x49, 0x46, 0x38],
            [0x25, 0x50, 0x44, 0x46, 0x2D],
            [0x50, 0x4B, 0x03, 0x04],
            [0x50, 0x4B, 0x05, 0x06],
            [0x50, 0x4B, 0x07, 0x08]
        ]

        if knownBinarySignatures.contains(where: { sample.starts(with: $0) }) {
            return true
        }

        var nulCount = 0
        var disallowedControlCount = 0

        for byte in sample {
            if byte == 0 { nulCount += 1 }
            if byte < 0x20,
               byte != 0x09,
               byte != 0x0A,
               byte != 0x0C,
               byte != 0x0D {
                disallowedControlCount += 1
            }
        }

        if nulCount > 0 { return true }
        return disallowedControlCount * 10 > sample.count
    }
}
