import Foundation

public struct MarkdownTextExtractor: TextFormatExtractor {
    public let format: TextExtractionFormat = .markdown
    public let supportedFileExtensions: Set<String> = TextExtractionFormat.markdown.fileExtensions
    public init() {}

    public func canExtract(data: Data, fileName: String?) -> Bool {
        guard let ext = FileName.fileExtension(from: fileName) else { return false }
        return supportedFileExtensions.contains(ext)
    }

    public func extract(data: Data, fileName: String?, sourceURL: URL?, options: TextExtractionOptions) throws -> ExtractedTextDocument {
        var text = try StringDecoder.decode(data, fileName: fileName)
        if options.markdownMode == .readableText { text = Self.convertToReadableText(text, options: options) }
        return ExtractedTextDocument(title: FileName.title(from: fileName, sourceURL: sourceURL), sourceURL: sourceURL,
            format: format, text: StringNormalizer.normalize(text, options: options))
    }

    static func convertToReadableText(_ markdown: String, options: TextExtractionOptions) -> String {
        var value = markdown.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        value = stripYAMLFrontMatter(value)
        if options.dropMarkdownCodeBlocks { value = stripCodeBlocks(value) }

        value = value.replacingOccurrences(of: #"!\[([^\]]*)\]\([^\n)]*\)"#, with: "$1", options: .regularExpression)
        value = value.replacingOccurrences(of: #"\[([^\]]+)\]\([^\n)]*\)"#, with: "$1", options: .regularExpression)
        value = value.replacingOccurrences(of: #"\[([^\]]+)\]\[[^\]]*\]"#, with: "$1", options: .regularExpression)
        value = value.replacingOccurrences(of: #"<https?://[^>]+>"#, with: "", options: [.regularExpression, .caseInsensitive])
        value = value.replacingOccurrences(of: #"<mailto:([^>]+)>"#, with: "$1", options: [.regularExpression, .caseInsensitive])

        let lines = value.components(separatedBy: "\n").map { source -> String in
            var line = source
            if line.range(of: #"^\s{0,3}\[[^\]]+\]:\s*\S+"#, options: .regularExpression) != nil { return "" }
            if line.range(of: #"^\s{0,3}(=+|-+)\s*$"#, options: .regularExpression) != nil { return "" }
            if line.range(of: #"^\s*\|?\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)+\|?\s*$"#, options: .regularExpression) != nil { return "" }

            line = line.replacingOccurrences(of: #"^\s{0,3}#{1,6}\s+"#, with: "", options: .regularExpression)
            line = line.replacingOccurrences(of: #"^\s*(>\s*)+"#, with: "", options: .regularExpression)
            line = line.replacingOccurrences(of: #"^\s*[-*+]\s+\[[ xX]\]\s+"#, with: "", options: .regularExpression)
            line = line.replacingOccurrences(of: #"^\s*[-*+]\s+"#, with: "", options: .regularExpression)
            line = line.replacingOccurrences(of: #"^\s*\d+[.)]\s+"#, with: "", options: .regularExpression)
            return line
        }

        value = lines.joined(separator: "\n")
        value = value.replacingOccurrences(of: #"`+([^`\n]*?)`+"#, with: "$1", options: .regularExpression)
        value = value.replacingOccurrences(of: #"(?<!\\)(\*\*|__)(.*?)(?<!\\)\1"#, with: "$2", options: .regularExpression)
        value = value.replacingOccurrences(of: #"(?<!\\)(\*|_)(.*?)(?<!\\)\1"#, with: "$2", options: .regularExpression)
        value = value.replacingOccurrences(of: #"~~(.*?)~~"#, with: "$1", options: .regularExpression)
        value = value.replacingOccurrences(of: #"\\([\\`*_{}\[\]()#+\-.!>])"#, with: "$1", options: .regularExpression)
        value = value.replacingOccurrences(of: "|", with: " ")
        value = BasicHTMLTextExtractor.stripTags(value)
        return HTMLEntityDecoder.decode(value)
    }

    private static func stripCodeBlocks(_ input: String) -> String {
        let lines = input.components(separatedBy: "\n")
        var output: [String] = []
        var activeFenceCharacter: Character?
        var activeFenceLength = 0

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let marker = fenceMarker(trimmed) {
                if let active = activeFenceCharacter {
                    if marker.character == active && marker.length >= activeFenceLength {
                        activeFenceCharacter = nil
                        activeFenceLength = 0
                        output.append("")
                    }
                } else {
                    activeFenceCharacter = marker.character
                    activeFenceLength = marker.length
                    output.append("")
                }
                continue
            }
            if activeFenceCharacter != nil { continue }
            if line.hasPrefix("    ") || line.hasPrefix("\t") { continue }
            output.append(line)
        }
        return output.joined(separator: "\n")
    }

    private static func fenceMarker(_ line: String) -> (character: Character, length: Int)? {
        guard let first = line.first, first == "`" || first == "~" else { return nil }
        let count = line.prefix { $0 == first }.count
        return count >= 3 ? (first, count) : nil
    }

    private static func stripYAMLFrontMatter(_ input: String) -> String {
        guard input.hasPrefix("---\n"),
              let range = input.range(of: "\n---\n", range: input.index(input.startIndex, offsetBy: 4)..<input.endIndex) else { return input }
        return String(input[range.upperBound...])
    }
}
