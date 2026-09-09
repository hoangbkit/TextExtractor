import Foundation

enum BasicHTMLTextExtractor {
    static func extractText(from data: Data, fileName: String?, options: TextExtractionOptions) throws -> String {
        let html = try StringDecoder.decode(data, fileName: fileName)
        return extractText(fromHTMLString: html, options: options)
    }

    static func extractText(fromHTMLString html: String, options: TextExtractionOptions) -> String {
        var value = html
        value = value.replacingOccurrences(of: #"(?s)<!--.*?-->"#, with: "\n", options: .regularExpression)
        value = value.replacingOccurrences(of: #"(?is)<(script|style|noscript)[^>]*>.*?</\1>"#, with: "\n", options: .regularExpression)
        value = value.replacingOccurrences(of: #"(?i)<br\s*/?>"#, with: "\n", options: .regularExpression)
        value = value.replacingOccurrences(of: #"(?i)<hr\s*/?>"#, with: "\n", options: .regularExpression)
        value = value.replacingOccurrences(of: #"(?i)</(p|div|section|article|header|footer|main|aside|nav|h[1-6]|li|tr|blockquote|pre)>"#, with: "\n", options: .regularExpression)
        value = value.replacingOccurrences(of: #"(?i)<li[^>]*>"#, with: "\n", options: .regularExpression)
        value = value.replacingOccurrences(of: #"(?i)</t[dh]>"#, with: "\t", options: .regularExpression)
        value = stripTags(value)
        value = HTMLEntityDecoder.decode(value)
        return StringNormalizer.normalize(value, options: options)
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
}
