import Foundation

enum BasicHTMLTextExtractor {
    private static let semanticBlockClosingTagPattern = #"(?i)</(p|div|section|article|header|footer|main|aside|nav|h[1-6]|li|tr|blockquote|pre)\s*>"#
    private static let horizontalRulePattern = #"(?i)<hr\b[^>]*>"#
    private static let fallbackBlockBoundaryMarker = "\u{E000}TEXTEXTRACTOR_BASIC_BLOCK_BOUNDARY\u{E001}"

    static func extractText(from data: Data, fileName: String?, options: TextExtractionOptions) throws -> String {
        let html = try StringDecoder.decode(data, fileName: fileName)
        return extractText(fromHTMLString: html, options: options)
    }

    static func extractText(fromHTMLString html: String, options: TextExtractionOptions) -> String {
        let paragraphBoundary = options.preserveParagraphs ? options.paragraphSeparator : "\n"

        var value = html
        value = value.replacingOccurrences(of: #"(?s)<!--.*?-->"#, with: "\n", options: .regularExpression)
        value = value.replacingOccurrences(of: #"(?is)<(script|style|noscript)[^>]*>.*?</\1>"#, with: "\n", options: .regularExpression)
        value = value.replacingOccurrences(of: #"(?i)<br\b[^>]*>"#, with: "\n", options: .regularExpression)
        value = value.replacingOccurrences(of: horizontalRulePattern, with: fallbackBlockBoundaryMarker, options: .regularExpression)
        value = value.replacingOccurrences(of: semanticBlockClosingTagPattern, with: fallbackBlockBoundaryMarker, options: .regularExpression)
        value = value.replacingOccurrences(of: #"(?i)<li\b[^>]*>"#, with: "\n", options: .regularExpression)
        value = value.replacingOccurrences(of: #"(?i)</t[dh]\s*>"#, with: "\t", options: .regularExpression)
        value = stripTags(value)
        value = HTMLEntityDecoder.decode(value)
        value = replacingBoundaryMarkers(
            in: value,
            marker: fallbackBlockBoundaryMarker,
            with: paragraphBoundary
        )
        return StringNormalizer.normalize(value, options: options)
    }

    /// Adds an out-of-band marker after semantic block boundaries while retaining
    /// the original tags. The native attributed-string HTML importer can then do
    /// its normal decoding, and callers can restore the marker to the configured
    /// paragraph separator without confusing `<br>` line breaks with paragraphs.
    static func insertingBlockBoundaryMarkers(in html: String, marker: String) -> String {
        var value = inserting(marker: marker, afterMatchesOf: semanticBlockClosingTagPattern, in: html)
        value = inserting(marker: marker, afterMatchesOf: horizontalRulePattern, in: value)
        return value
    }

    static func stripTags(_ string: String) -> String {
        var output = ""
        var insideTag = false
        var quote: Character?
        var index = string.startIndex

        while index < string.endIndex {
            let character = string[index]
            if insideTag {
                if let activeQuote = quote {
                    if character == activeQuote { quote = nil }
                } else if character == "\"" || character == "'" {
                    quote = character
                } else if character == ">" {
                    insideTag = false
                    output.append(" ")
                }
            } else if character == "<" {
                let next = string.index(after: index)
                if next < string.endIndex {
                    let candidate = string[next]
                    if candidate.isLetter || candidate == "/" || candidate == "!" || candidate == "?" {
                        insideTag = true
                    } else {
                        output.append(character)
                    }
                } else {
                    output.append(character)
                }
            } else {
                output.append(character)
            }
            index = string.index(after: index)
        }
        return output
    }

    private static func replacingBoundaryMarkers(in text: String, marker: String, with separator: String) -> String {
        var output = text

        while let markerRange = output.range(of: marker) {
            var lowerBound = markerRange.lowerBound
            while lowerBound > output.startIndex {
                let previous = output.index(before: lowerBound)
                guard isBoundaryWhitespace(output[previous]) else { break }
                lowerBound = previous
            }

            var upperBound = markerRange.upperBound
            while upperBound < output.endIndex {
                guard isBoundaryWhitespace(output[upperBound]) else { break }
                upperBound = output.index(after: upperBound)
            }

            let isAtDocumentEdge = lowerBound == output.startIndex || upperBound == output.endIndex
            output.replaceSubrange(lowerBound..<upperBound, with: isAtDocumentEdge ? "" : separator)
        }

        return output
    }

    private static func isBoundaryWhitespace(_ character: Character) -> Bool {
        character == " " || character == "\t" || character == "\n" || character == "\r"
            || character == "\u{2028}" || character == "\u{2029}"
    }

    private static func inserting(marker: String, afterMatchesOf pattern: String, in input: String) -> String {
        guard !marker.isEmpty,
              let regex = try? NSRegularExpression(pattern: pattern) else {
            return input
        }

        var output = input
        let range = NSRange(input.startIndex..<input.endIndex, in: input)
        for match in regex.matches(in: input, range: range).reversed() {
            guard let matchRange = Range(match.range, in: output) else { continue }
            output.insert(contentsOf: marker, at: matchRange.upperBound)
        }
        return output
    }
}
