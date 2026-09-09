import Foundation

enum StringDecoder {
    struct DecodedText {
        var string: String
        var encodingName: String
        var usedLegacyFallback: Bool
    }

    static func decode(_ data: Data, fileName: String?) throws -> String {
        try decodeWithEncoding(data, fileName: fileName).string
    }

    static func decodeWithEncoding(_ data: Data, fileName: String?) throws -> DecodedText {
        if data.isEmpty { return DecodedText(string: "", encodingName: "empty", usedLegacyFallback: false) }

        if hasRecognizedBOM(data) {
            guard let result = decodeUsingBOM(data) else {
                throw TextExtractionError.unreadableTextEncoding(fileName: fileName)
            }
            return result
        }

        if let result = decodeLikelyUTF16WithoutBOM(data) { return result }

        if let string = String(data: data, encoding: .utf8) {
            return DecodedText(string: string, encodingName: "utf-8", usedLegacyFallback: false)
        }

        guard !isLikelyBinary(data) else {
            throw TextExtractionError.unreadableTextEncoding(fileName: fileName)
        }

        if let string = String(data: data, encoding: .windowsCP1252) {
            return DecodedText(string: string, encodingName: "windows-1252", usedLegacyFallback: true)
        }
        if let string = String(data: data, encoding: .isoLatin1) {
            return DecodedText(string: string, encodingName: "iso-8859-1", usedLegacyFallback: true)
        }
        throw TextExtractionError.unreadableTextEncoding(fileName: fileName)
    }

    private static func hasRecognizedBOM(_ data: Data) -> Bool {
        let bytes = [UInt8](data.prefix(3))
        return bytes.starts(with: [0xEF, 0xBB, 0xBF]) || bytes.starts(with: [0xFF, 0xFE]) || bytes.starts(with: [0xFE, 0xFF])
    }

    private static func decodeUsingBOM(_ data: Data) -> DecodedText? {
        let bytes = [UInt8](data.prefix(4))
        if bytes.starts(with: [0xEF, 0xBB, 0xBF]) {
            guard let string = String(data: data.dropFirst(3), encoding: .utf8) else { return nil }
            return DecodedText(string: string, encodingName: "utf-8-bom", usedLegacyFallback: false)
        }
        if bytes.starts(with: [0xFF, 0xFE]) {
            guard (data.count - 2).isMultiple(of: 2), let string = String(data: data.dropFirst(2), encoding: .utf16LittleEndian) else { return nil }
            return DecodedText(string: string, encodingName: "utf-16le-bom", usedLegacyFallback: false)
        }
        if bytes.starts(with: [0xFE, 0xFF]) {
            guard (data.count - 2).isMultiple(of: 2), let string = String(data: data.dropFirst(2), encoding: .utf16BigEndian) else { return nil }
            return DecodedText(string: string, encodingName: "utf-16be-bom", usedLegacyFallback: false)
        }
        return nil
    }

    private static func decodeLikelyUTF16WithoutBOM(_ data: Data) -> DecodedText? {
        guard data.count >= 4, data.count.isMultiple(of: 2) else { return nil }
        let bytes = [UInt8](data.prefix(2_048)); let pairCount = bytes.count / 2
        guard pairCount >= 2 else { return nil }
        var evenZeros = 0, oddZeros = 0
        for i in 0..<pairCount {
            if bytes[i * 2] == 0 { evenZeros += 1 }
            if bytes[i * 2 + 1] == 0 { oddZeros += 1 }
        }
        let strong = max(2, pairCount / 3), weak = max(1, pairCount / 20)
        if oddZeros >= strong, evenZeros <= weak, let string = String(data: data, encoding: .utf16LittleEndian) {
            return DecodedText(string: string, encodingName: "utf-16le-inferred", usedLegacyFallback: false)
        }
        if evenZeros >= strong, oddZeros <= weak, let string = String(data: data, encoding: .utf16BigEndian) {
            return DecodedText(string: string, encodingName: "utf-16be-inferred", usedLegacyFallback: false)
        }
        return nil
    }

    private static func isLikelyBinary(_ data: Data) -> Bool {
        let sample = [UInt8](data.prefix(4_096)); guard !sample.isEmpty else { return false }
        let signatures: [[UInt8]] = [[0x89,0x50,0x4E,0x47],[0xFF,0xD8,0xFF],[0x47,0x49,0x46,0x38],[0x25,0x50,0x44,0x46,0x2D],[0x50,0x4B,0x03,0x04],[0x50,0x4B,0x05,0x06],[0x50,0x4B,0x07,0x08]]
        if signatures.contains(where: { sample.starts(with: $0) }) { return true }
        var nul = 0, controls = 0
        for byte in sample {
            if byte == 0 { nul += 1 }
            if byte < 0x20, ![0x09,0x0A,0x0C,0x0D].contains(byte) { controls += 1 }
        }
        return nul > 0 || controls * 10 > sample.count
    }
}
