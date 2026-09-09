import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

struct DOCXTextBlock: Equatable {
    var text: String
    var numberingID: String?
    var numberingLevel: Int?
    var isTableRow: Bool
}

enum DOCXXMLTextParser {
    static func parseParagraphs(from data: Data) throws -> [String] {
        try parseBlocks(from: data).map(\.text)
    }

    static func parseBlocks(from data: Data) throws -> [DOCXTextBlock] {
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
        private(set) var blocks: [DOCXTextBlock] = []

        private var paragraph = ""
        private var paragraphDepth = 0
        private var paragraphNumberingID: String?
        private var paragraphNumberingLevel: Int?
        private var numberingPropertiesDepth = 0

        private var isCapturingText = false
        private var deletedDepth = 0
        private var instructionDepth = 0
        private var ignoredContainerDepth = 0

        private var tableDepth = 0
        private var cellDepth = 0
        private var cellParagraphs: [String] = []
        private var rowCells: [String] = []

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

            if (name == "footnote" || name == "endnote"),
               let id = attributeValue(named: "id", in: attributeDict),
               id == "-1" || id == "0" {
                ignoredContainerDepth = 1
                return
            }

            switch name {
            case "del", "delText":
                deletedDepth += 1
            case "instrText":
                instructionDepth += 1
            case "tbl":
                tableDepth += 1
            case "tr":
                if tableDepth == 1 { rowCells = [] }
            case "tc":
                if tableDepth == 1 {
                    cellDepth = 1
                    cellParagraphs = []
                } else if cellDepth > 0 {
                    cellDepth += 1
                }
            case "p":
                paragraphDepth += 1
                if paragraphDepth == 1 {
                    paragraph = ""
                    paragraphNumberingID = nil
                    paragraphNumberingLevel = nil
                    numberingPropertiesDepth = 0
                }
            case "numPr":
                if paragraphDepth > 0 { numberingPropertiesDepth += 1 }
            case "numId":
                if paragraphDepth > 0, numberingPropertiesDepth > 0 {
                    paragraphNumberingID = attributeValue(named: "val", in: attributeDict)
                }
            case "ilvl":
                if paragraphDepth > 0, numberingPropertiesDepth > 0,
                   let raw = attributeValue(named: "val", in: attributeDict) {
                    paragraphNumberingLevel = Int(raw)
                }
            case "t":
                if deletedDepth == 0 && instructionDepth == 0 {
                    isCapturingText = true
                }
            case "tab":
                appendIfVisible("\t")
            case "br", "cr":
                appendIfVisible("\n")
            default:
                break
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            guard isCapturingText, ignoredContainerDepth == 0, deletedDepth == 0, instructionDepth == 0 else { return }
            paragraph.append(string)
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
            case "t":
                isCapturingText = false
            case "numPr":
                numberingPropertiesDepth = max(0, numberingPropertiesDepth - 1)
            case "p":
                paragraphDepth = max(0, paragraphDepth - 1)
                if paragraphDepth == 0 { flushParagraph() }
            case "tc":
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
            case "tr":
                if tableDepth == 1 {
                    let row = rowCells.joined(separator: "\t")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !row.isEmpty {
                        blocks.append(DOCXTextBlock(text: row, numberingID: nil, numberingLevel: nil, isTableRow: true))
                    }
                    rowCells = []
                }
            case "tbl":
                tableDepth = max(0, tableDepth - 1)
            case "del", "delText":
                deletedDepth = max(0, deletedDepth - 1)
            case "instrText":
                instructionDepth = max(0, instructionDepth - 1)
            default:
                break
            }
        }

        private func appendIfVisible(_ string: String) {
            guard paragraphDepth > 0, ignoredContainerDepth == 0, deletedDepth == 0, instructionDepth == 0 else { return }
            paragraph.append(string)
        }

        private func flushParagraph() {
            let cleaned = paragraph
                .replacingOccurrences(of: #" {2,}"#, with: " ", options: .regularExpression)
                .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !cleaned.isEmpty {
                if tableDepth > 0 && cellDepth > 0 {
                    cellParagraphs.append(cleaned)
                } else {
                    blocks.append(
                        DOCXTextBlock(
                            text: cleaned,
                            numberingID: paragraphNumberingID,
                            numberingLevel: paragraphNumberingLevel,
                            isTableRow: false
                        )
                    )
                }
            }

            paragraph = ""
            paragraphNumberingID = nil
            paragraphNumberingLevel = nil
            numberingPropertiesDepth = 0
        }

        private func attributeValue(named target: String, in attributes: [String: String]) -> String? {
            for (key, value) in attributes where localName(key) == target { return value }
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
