import Foundation

enum BasicHTMLTextExtractor {
    static func extractText(from data: Data, fileName: String?, options: TextExtractionOptions) throws -> String {
        let html = try StringDecoder.decode(data, fileName: fileName)
        return extractText(fromHTMLString: html, options: options)
    }

    static func extractText(fromHTMLString html: String, options: TextExtractionOptions) -> String {
        var value = html
        value = value.replacingOccurrences(of: #"(?is)<(script|style|noscript)[^>]*>.*?</\1>"#, with: "\n", options: .regularExpression)
        value = value.replacingOccurrences(of: #"(?i)<br\s*/?>"#, with: "\n", options: .regularExpression)
        value = value.replacingOccurrences(of: #"(?i)</(p|div|section|article|header|footer|h[1-6]|li|tr|blockquote)>"#, with: "\n", options: .regularExpression)
        value = value.replacingOccurrences(of: #"(?i)<li[^>]*>"#, with: "\n", options: .regularExpression)
        value = value.replacingOccurrences(of: #"(?i)</t[dh]>"#, with: "\t", options: .regularExpression)
        value = stripTags(value)
        value = HTMLEntityDecoder.decode(value)
        return StringNormalizer.normalize(value, options: options)
    }

    static func stripTags(_ string: String) -> String {
        string.replacingOccurrences(of: #"(?s)<[^>]+>"#, with: " ", options: .regularExpression)
    }
}
