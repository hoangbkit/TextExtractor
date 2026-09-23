import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

struct ODTTextBlock: Equatable {
    var text: String
    var isTableRow: Bool
}

enum ODTXMLTextParser {
    static func parseBlocks(from data: Data) throws -> [ODTTextBlock] {
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

        return delegate.blocks
    }

    private final class Delegate: NSObject, XMLParserDelegate {
        private(set) var blocks: [ODTTextBlock] = []

        private var paragraph = ""
        private var paragraphDepth = 0
        private var paragraphListDepth = 0

        private var listDepth = 0
        private var listItemDepth = 0

        private var tableDepth = 0
        private var cellDepth = 0
        private var cellParagraphs: [String] = []
        private var rowCells: [String] = []

        private var ignoredContainerDepth = 0

        func parser(
            _ parser: XMLParser,
            didStartElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?,
            attributes attributeDict: [String: String] = [:]
        ) {
            if ignoredContainerDepth > 0 {
                ignoredContainerDepth += 1
                return
            }

            let name = localName(elementName)

            if name == "tracked-changes" || name == "annotation" {
                ignoredContainerDepth = 1
                return
            }

            switch name {
            case "list":
                listDepth += 1
            case "list-item":
                listItemDepth += 1
            case "table":
                tableDepth += 1
            case "table-row":
                if tableDepth == 1 {
                    rowCells = []
                }
            case "table-cell", "covered-table-cell":
                if tableDepth == 1 {
                    cellDepth = 1
                    cellParagraphs = []
                } else if cellDepth > 0 {
                    cellDepth += 1
                }
            case "p", "h":
                paragraphDepth += 1
                if paragraphDepth == 1 {
                    paragraph = ""
                    paragraphListDepth = listItemDepth > 0 ? listDepth : 0
                } else {
                    appendIfInParagraph(" ")
                }
            case "tab":
                appendIfInParagraph("\t")
            case "line-break":
                appendIfInParagraph("\n")
            case "s":
                let requested = Int(attributeValue(named: "c", in: attributeDict) ?? "1") ?? 1
                let count = min(max(requested, 1), 1_024)
                appendIfInParagraph(String(repeating: " ", count: count))
            default:
                break
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            appendIfInParagraph(string)
        }

        func parser(
            _ parser: XMLParser,
            didEndElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?
        ) {
            if ignoredContainerDepth > 0 {
                ignoredContainerDepth -= 1
                return
            }

            let name = localName(elementName)

            switch name {
            case "p", "h":
                paragraphDepth = max(0, paragraphDepth - 1)
                if paragraphDepth == 0 {
                    flushParagraph()
                }
            case "table-cell", "covered-table-cell":
                if tableDepth == 1, cellDepth == 1 {
                    let cell = cellParagraphs
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                        .joined(separator: " ")
                    rowCells.append(cell)
                    cellParagraphs = []
                    cellDepth = 0
                } else if cellDepth > 0 {
                    cellDepth -= 1
                }
            case "table-row":
                if tableDepth == 1 {
                    let row = rowCells
                        .joined(separator: "\t")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !row.isEmpty {
                        blocks.append(ODTTextBlock(text: row, isTableRow: true))
                    }
                    rowCells = []
                }
            case "table":
                tableDepth = max(0, tableDepth - 1)
            case "list-item":
                listItemDepth = max(0, listItemDepth - 1)
            case "list":
                listDepth = max(0, listDepth - 1)
            default:
                break
            }
        }

        private func appendIfInParagraph(_ string: String) {
            guard paragraphDepth > 0, ignoredContainerDepth == 0 else { return }
            paragraph.append(string)
        }

        private func flushParagraph() {
            var cleaned = paragraph
                .replacingOccurrences(of: #" {2,}"#, with: " ", options: .regularExpression)
                .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !cleaned.isEmpty {
                if tableDepth > 0 && cellDepth > 0 {
                    cellParagraphs.append(cleaned)
                } else {
                    if paragraphListDepth > 0 {
                        cleaned = "• \(cleaned)"
                    }
                    blocks.append(ODTTextBlock(text: cleaned, isTableRow: false))
                }
            }

            paragraph = ""
            paragraphListDepth = 0
        }

        private func attributeValue(named target: String, in attributes: [String: String]) -> String? {
            for (key, value) in attributes where localName(key) == target {
                return value
            }
            return nil
        }

        private func localName(_ name: String) -> String {
            if let index = name.lastIndex(of: ":") {
                return String(name[name.index(after: index)...])
            }
            return name
        }
    }
}
