import Foundation

enum StringNormalizer {
    static func normalize(_ text: String, options: TextExtractionOptions) -> String {
        var value = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\u{200B}", with: "")

        value = removeUnsafeControlCharacters(value)

        guard options.normalizeWhitespace else {
            return value.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let lines = value.components(separatedBy: "\n").map { line in
            line.replacingOccurrences(of: #"[ \t]+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
        }

        if options.preserveParagraphs {
            value = lines.joined(separator: "\n")
            value = value.replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
        } else {
            value = lines.joined(separator: " ")
            value = value.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        }

        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func joinParagraphs(_ paragraphs: [String], separator: String) -> String {
        paragraphs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: separator)
    }

    private static func removeUnsafeControlCharacters(_ string: String) -> String {
        String(string.unicodeScalars.filter { scalar in
            scalar == "\n" || scalar == "\t" || scalar.value >= 32
        })
    }
}
