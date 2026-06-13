import Foundation

public struct MarkdownTextExtractor: TextFormatExtractor {
    public let format: TextExtractionFormat = .markdown
    public let supportedFileExtensions: Set<String> = TextExtractionFormat.markdown.fileExtensions

    public init() {}

    public func canExtract(data: Data, fileName: String?) -> Bool {
        guard let ext = FileName.fileExtension(from: fileName) else { return false }
        return supportedFileExtensions.contains(ext)
    }

    public func extract(
        data: Data,
        fileName: String?,
        sourceURL: URL?,
        options: TextExtractionOptions
    ) throws -> ExtractedTextDocument {
        var text = try StringDecoder.decode(data, fileName: fileName)

        if options.markdownMode == .readableText {
            text = Self.convertToReadableText(text, options: options)
        }

        text = StringNormalizer.normalize(text, options: options)

        return ExtractedTextDocument(
            title: FileName.title(from: fileName, sourceURL: sourceURL),
            sourceURL: sourceURL,
            format: format,
            text: text
        )
    }

    static func convertToReadableText(_ markdown: String, options: TextExtractionOptions) -> String {
        var value = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        value = stripYAMLFrontMatter(value)

        if options.dropMarkdownCodeBlocks {
            value = value.replacingOccurrences(
                of: #"(?s)```.*?```"#,
                with: "\n",
                options: .regularExpression
            )
            value = value.replacingOccurrences(
                of: #"(?s)~~~.*?~~~"#,
                with: "\n",
                options: .regularExpression
            )
        }

        value = value.replacingOccurrences(of: #"!\[([^\]]*)\]\([^\)]*\)"#, with: "$1", options: .regularExpression)
        value = value.replacingOccurrences(of: #"\[([^\]]+)\]\([^\)]*\)"#, with: "$1", options: .regularExpression)
        value = value.replacingOccurrences(of: #"\[([^\]]+)\]\[[^\]]*\]"#, with: "$1", options: .regularExpression)
        value = value.replacingOccurrences(of: #"^\s{0,3}#{1,6}\s+"#, with: "", options: [.regularExpression, .anchored])

        let lines = value.components(separatedBy: "\n").map { line -> String in
            var line = line
            line = line.replacingOccurrences(of: #"^\s{0,3}#{1,6}\s+"#, with: "", options: .regularExpression)
            line = line.replacingOccurrences(of: #"^\s{0,3}>\s?"#, with: "", options: .regularExpression)
            line = line.replacingOccurrences(of: #"^\s*[-*+]\s+"#, with: "", options: .regularExpression)
            line = line.replacingOccurrences(of: #"^\s*\d+[.)]\s+"#, with: "", options: .regularExpression)
            line = line.replacingOccurrences(of: #"^\s{0,3}[-*_]{3,}\s*$"#, with: "", options: .regularExpression)
            line = line.replacingOccurrences(of: #"^\s*[:\-\| ]{3,}\s*$"#, with: "", options: .regularExpression)
            return line
        }

        value = lines.joined(separator: "\n")
        value = value.replacingOccurrences(of: #"`([^`]*)`"#, with: "$1", options: .regularExpression)
        value = value.replacingOccurrences(of: #"(\*\*|__)(.*?)\1"#, with: "$2", options: .regularExpression)
        value = value.replacingOccurrences(of: #"(\*|_)(.*?)\1"#, with: "$2", options: .regularExpression)
        value = value.replacingOccurrences(of: #"~~(.*?)~~"#, with: "$1", options: .regularExpression)
        value = value.replacingOccurrences(of: #"\|"#, with: " ", options: .regularExpression)
        value = BasicHTMLTextExtractor.stripTags(value)
        return HTMLEntityDecoder.decode(value)
    }

    private static func stripYAMLFrontMatter(_ input: String) -> String {
        guard input.hasPrefix("---\n") else { return input }
        guard let range = input.range(of: "\n---\n", options: [], range: input.index(input.startIndex, offsetBy: 4)..<input.endIndex) else {
            return input
        }
        return String(input[range.upperBound...])
    }
}
