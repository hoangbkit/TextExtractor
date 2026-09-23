import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

struct PPTXTextBlock: Equatable {
    var text: String
    var isTableRow: Bool
}

struct PPTXRelationship: Equatable {
    var id: String
    var type: String
    var target: String
    var isExternal: Bool
}

enum PPTXXMLParser {
    static func parseSlideRelationshipIDs(from data: Data) throws -> [String] {
        let delegate = SlideListDelegate()
        try parse(data, delegate: delegate)
        return delegate.relationshipIDs
    }

    static func parseRelationships(from data: Data) throws -> [PPTXRelationship] {
        let delegate = RelationshipsDelegate()
        try parse(data, delegate: delegate)
        return delegate.relationships
    }

    static func parseTextBlocks(
        from data: Data,
        ignoredPlaceholderTypes: Set<String> = []
    ) throws -> [PPTXTextBlock] {
        let delegate = TextDelegate(ignoredPlaceholderTypes: ignoredPlaceholderTypes)
        try parse(data, delegate: delegate)
        return delegate.blocks
    }

    private static func parse(_ data: Data, delegate: XMLParserDelegate) throws {
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldProcessNamespaces = false
        parser.shouldReportNamespacePrefixes = false
        parser.shouldResolveExternalEntities = false

        guard parser.parse() else {
            if let error = parser.parserError { throw error }
            throw TextExtractionError.invalidDocument(reason: "Unknown PPTX XML parser error.")
        }
    }

    private final class SlideListDelegate: NSObject, XMLParserDelegate {
        private(set) var relationshipIDs: [String] = []

        func parser(
            _ parser: XMLParser,
            didStartElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?,
            attributes attributeDict: [String: String] = [:]
        ) {
            guard PPTXXMLParser.localName(elementName) == "sldId" else { return }

            if let exact = attributeDict["r:id"] {
                relationshipIDs.append(exact)
                return
            }

            if let relationshipID = attributeDict.first(where: {
                $0.key.lowercased().hasSuffix(":id")
            })?.value {
                relationshipIDs.append(relationshipID)
            }
        }
    }

    private final class RelationshipsDelegate: NSObject, XMLParserDelegate {
        private(set) var relationships: [PPTXRelationship] = []

        func parser(
            _ parser: XMLParser,
            didStartElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?,
            attributes attributeDict: [String: String] = [:]
        ) {
            guard PPTXXMLParser.localName(elementName) == "Relationship",
                  let id = PPTXXMLParser.attributeValue(named: "Id", in: attributeDict),
                  let type = PPTXXMLParser.attributeValue(named: "Type", in: attributeDict),
                  let target = PPTXXMLParser.attributeValue(named: "Target", in: attributeDict) else {
                return
            }

            relationships.append(
                PPTXRelationship(
                    id: id,
                    type: type,
                    target: target,
                    isExternal: PPTXXMLParser.attributeValue(named: "TargetMode", in: attributeDict)?
                        .caseInsensitiveCompare("External") == .orderedSame
                )
            )
        }
    }

    private final class TextDelegate: NSObject, XMLParserDelegate {
        private(set) var blocks: [PPTXTextBlock] = []

        private let ignoredPlaceholderTypes: Set<String>

        private var shapeDepth = 0
        private var currentShapeIgnored = false

        private var paragraph = ""
        private var paragraphDepth = 0
        private var isCapturingText = false

        private var tableDepth = 0
        private var cellDepth = 0
        private var cellParagraphs: [String] = []
        private var rowCells: [String] = []

        init(ignoredPlaceholderTypes: Set<String>) {
            self.ignoredPlaceholderTypes = Set(ignoredPlaceholderTypes.map { $0.lowercased() })
        }

        func parser(
            _ parser: XMLParser,
            didStartElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?,
            attributes attributeDict: [String: String] = [:]
        ) {
            let name = PPTXXMLParser.localName(elementName)

            switch name {
            case "sp":
                shapeDepth += 1
                if shapeDepth == 1 {
                    currentShapeIgnored = false
                }
            case "ph":
                if shapeDepth > 0,
                   let type = PPTXXMLParser.attributeValue(named: "type", in: attributeDict)?.lowercased(),
                   ignoredPlaceholderTypes.contains(type) {
                    currentShapeIgnored = true
                }
            case "tbl":
                tableDepth += 1
            case "tr":
                if tableDepth == 1 {
                    rowCells = []
                }
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
                }
            case "t":
                if isVisible {
                    isCapturingText = true
                }
            case "br":
                appendIfVisible("\n")
            case "tab":
                appendIfVisible("\t")
            default:
                break
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            guard isCapturingText, isVisible else { return }
            paragraph.append(string)
        }

        func parser(
            _ parser: XMLParser,
            didEndElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?
        ) {
            let name = PPTXXMLParser.localName(elementName)

            switch name {
            case "t":
                isCapturingText = false
            case "p":
                paragraphDepth = max(0, paragraphDepth - 1)
                if paragraphDepth == 0 {
                    flushParagraph()
                }
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
                    let row = rowCells
                        .joined(separator: "\t")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !row.isEmpty {
                        blocks.append(PPTXTextBlock(text: row, isTableRow: true))
                    }
                    rowCells = []
                }
            case "tbl":
                tableDepth = max(0, tableDepth - 1)
            case "sp":
                shapeDepth = max(0, shapeDepth - 1)
                if shapeDepth == 0 {
                    currentShapeIgnored = false
                }
            default:
                break
            }
        }

        private var isVisible: Bool {
            paragraphDepth > 0 && (shapeDepth == 0 || !currentShapeIgnored)
        }

        private func appendIfVisible(_ string: String) {
            guard isVisible else { return }
            paragraph.append(string)
        }

        private func flushParagraph() {
            let cleaned = paragraph
                .replacingOccurrences(of: #" {2,}"#, with: " ", options: .regularExpression)
                .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !cleaned.isEmpty, shapeDepth == 0 || !currentShapeIgnored {
                if tableDepth > 0 && cellDepth > 0 {
                    cellParagraphs.append(cleaned)
                } else {
                    blocks.append(PPTXTextBlock(text: cleaned, isTableRow: false))
                }
            }

            paragraph = ""
        }
    }

    private static func attributeValue(named target: String, in attributes: [String: String]) -> String? {
        if let exact = attributes[target] {
            return exact
        }

        for (key, value) in attributes where localName(key).caseInsensitiveCompare(target) == .orderedSame {
            return value
        }
        return nil
    }

    private static func localName(_ name: String) -> String {
        if let index = name.lastIndex(of: ":") {
            return String(name[name.index(after: index)...])
        }
        return name
    }
}
