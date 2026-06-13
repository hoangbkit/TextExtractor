import Foundation

enum HTMLEntityDecoder {
    private static let named: [String: String] = [
        "amp": "&",
        "lt": "<",
        "gt": ">",
        "quot": "\"",
        "apos": "'",
        "nbsp": " ",
        "ndash": "–",
        "mdash": "—",
        "hellip": "…",
        "lsquo": "‘",
        "rsquo": "’",
        "ldquo": "“",
        "rdquo": "”",
        "copy": "©",
        "reg": "®",
        "trade": "™"
    ]

    static func decode(_ input: String) -> String {
        let pattern = #"&(#x[0-9A-Fa-f]+|#\d+|[A-Za-z][A-Za-z0-9]+);"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return input }

        let nsRange = NSRange(input.startIndex..<input.endIndex, in: input)
        var output = input
        let matches = regex.matches(in: input, range: nsRange).reversed()

        for match in matches {
            guard let fullRange = Range(match.range(at: 0), in: output),
                  let entityRange = Range(match.range(at: 1), in: output) else { continue }

            let entity = String(output[entityRange])
            if let replacement = replacement(for: entity) {
                output.replaceSubrange(fullRange, with: replacement)
            }
        }

        return output
    }

    private static func replacement(for entity: String) -> String? {
        if entity.hasPrefix("#x") || entity.hasPrefix("#X") {
            let hex = String(entity.dropFirst(2))
            guard let value = UInt32(hex, radix: 16), let scalar = UnicodeScalar(value) else { return nil }
            return String(Character(scalar))
        }

        if entity.hasPrefix("#") {
            let decimal = String(entity.dropFirst())
            guard let value = UInt32(decimal, radix: 10), let scalar = UnicodeScalar(value) else { return nil }
            return String(Character(scalar))
        }

        return named[entity]
    }
}
