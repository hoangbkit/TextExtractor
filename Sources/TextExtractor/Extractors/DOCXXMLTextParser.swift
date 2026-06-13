import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

enum DOCXXMLTextParser {
    static func parseParagraphs(from data: Data) throws -> [String] {
        let delegate = Delegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldProcessNamespaces = false
        parser.shouldReportNamespacePrefixes = false
        parser.shouldResolveExternalEntities = false

        guard parser.parse() else {
            if let error = parser.parserError { throw error }
            throw TextExtractionError.invalidDocument(reason: "Unknown XML parser error.")
        }

        return delegate.paragraphs
    }

    private final class Delegate: NSObject, XMLParserDelegate {
        private(set) var paragraphs: [String] = []

        private var paragraph = ""
        private var isCapturingText = false
        private var isIgnoringDeletedText = false
        private var isIgnoringFieldCode = false
        private var paragraphDepth = 0

        func parser(
            _ parser: XMLParser,
            didStartElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?,
            attributes attributeDict: [String: String] = [:]
        ) {
            let name = localName(elementName)

            switch name {
            case "p":
                paragraphDepth += 1
                if paragraphDepth == 1 { paragraph = "" }
            case "t":
                if !isIgnoringDeletedText && !isIgnoringFieldCode {
                    isCapturingText = true
                }
            case "tab":
                append("\t")
            case "br", "cr":
                append("\n")
            case "tc":
                if !paragraph.isEmpty, !paragraph.hasSuffix("\t"), !paragraph.hasSuffix("\n") {
                    append("\t")
                }
            case "del", "delText":
                isIgnoringDeletedText = true
            case "instrText":
                isIgnoringFieldCode = true
            default:
                break
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            guard isCapturingText else { return }
            append(string)
        }

        func parser(
            _ parser: XMLParser,
            didEndElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?
        ) {
            let name = localName(elementName)

            switch name {
            case "t":
                isCapturingText = false
            case "p":
                paragraphDepth = max(0, paragraphDepth - 1)
                if paragraphDepth == 0 {
                    flushParagraph()
                }
            case "del", "delText":
                isIgnoringDeletedText = false
            case "instrText":
                isIgnoringFieldCode = false
            default:
                break
            }
        }

        private func append(_ string: String) {
            paragraph.append(string)
        }

        private func flushParagraph() {
            let cleaned = paragraph
                .replacingOccurrences(of: #"[ \t]+"#, with: " ", options: .regularExpression)
                .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !cleaned.isEmpty {
                paragraphs.append(cleaned)
            }
            paragraph = ""
        }

        private func localName(_ name: String) -> String {
            if let index = name.lastIndex(of: ":") {
                return String(name[name.index(after: index)...])
            }
            return name
        }
    }
}
