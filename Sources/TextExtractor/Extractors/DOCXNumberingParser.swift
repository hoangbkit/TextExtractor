import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

struct DOCXNumberingDefinition {
    struct Level: Equatable {
        var format: String
        var text: String
        var start: Int
    }

    var abstractLevels: [String: [Int: Level]]
    var numToAbstract: [String: String]
    var startOverrides: [String: [Int: Int]]
}

enum DOCXNumberingParser {
    static func parse(from data: Data) throws -> DOCXNumberingDefinition {
        let delegate = Delegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldProcessNamespaces = false
        parser.shouldReportNamespacePrefixes = false
        parser.shouldResolveExternalEntities = false

        guard parser.parse() else {
            if let error = parser.parserError { throw error }
            throw TextExtractionError.invalidDocument(reason: "Unknown numbering XML parser error.")
        }

        return DOCXNumberingDefinition(
            abstractLevels: delegate.abstractLevels,
            numToAbstract: delegate.numToAbstract,
            startOverrides: delegate.startOverrides
        )
    }

    private final class Delegate: NSObject, XMLParserDelegate {
        private(set) var abstractLevels: [String: [Int: DOCXNumberingDefinition.Level]] = [:]
        private(set) var numToAbstract: [String: String] = [:]
        private(set) var startOverrides: [String: [Int: Int]] = [:]

        private var currentAbstractID: String?
        private var currentLevelIndex: Int?
        private var currentLevelFormat = "decimal"
        private var currentLevelText = "%1."
        private var currentLevelStart = 1

        private var currentNumID: String?
        private var currentOverrideLevel: Int?

        func parser(
            _ parser: XMLParser,
            didStartElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?,
            attributes attributeDict: [String: String] = [:]
        ) {
            let name = localName(elementName)
            switch name {
            case "abstractNum":
                currentAbstractID = attributeValue(named: "abstractNumId", in: attributeDict)
            case "lvl":
                currentLevelIndex = attributeValue(named: "ilvl", in: attributeDict).flatMap(Int.init)
                currentLevelFormat = "decimal"
                currentLevelText = "%1."
                currentLevelStart = 1
            case "numFmt":
                if currentLevelIndex != nil, let value = attributeValue(named: "val", in: attributeDict) {
                    currentLevelFormat = value
                }
            case "lvlText":
                if currentLevelIndex != nil, let value = attributeValue(named: "val", in: attributeDict) {
                    currentLevelText = value
                }
            case "start":
                if currentLevelIndex != nil, let value = attributeValue(named: "val", in: attributeDict).flatMap(Int.init) {
                    currentLevelStart = value
                }
            case "num":
                currentNumID = attributeValue(named: "numId", in: attributeDict)
            case "abstractNumId":
                if let currentNumID, let abstractID = attributeValue(named: "val", in: attributeDict) {
                    numToAbstract[currentNumID] = abstractID
                }
            case "lvlOverride":
                currentOverrideLevel = attributeValue(named: "ilvl", in: attributeDict).flatMap(Int.init)
            case "startOverride":
                if let currentNumID, let level = currentOverrideLevel,
                   let value = attributeValue(named: "val", in: attributeDict).flatMap(Int.init) {
                    startOverrides[currentNumID, default: [:]][level] = value
                }
            default:
                break
            }
        }

        func parser(
            _ parser: XMLParser,
            didEndElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?
        ) {
            switch localName(elementName) {
            case "lvl":
                if let abstractID = currentAbstractID, let level = currentLevelIndex {
                    abstractLevels[abstractID, default: [:]][level] = DOCXNumberingDefinition.Level(
                        format: currentLevelFormat,
                        text: currentLevelText,
                        start: currentLevelStart
                    )
                }
                currentLevelIndex = nil
            case "abstractNum":
                currentAbstractID = nil
            case "lvlOverride":
                currentOverrideLevel = nil
            case "num":
                currentNumID = nil
            default:
                break
            }
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

struct DOCXNumberingResolver {
    private let definition: DOCXNumberingDefinition
    private var counters: [String: [Int: Int]] = [:]

    init(definition: DOCXNumberingDefinition) {
        self.definition = definition
    }

    mutating func label(numID: String, level: Int) -> String? {
        guard let abstractID = definition.numToAbstract[numID],
              let levelDefinition = definition.abstractLevels[abstractID]?[level] else {
            return nil
        }

        var numCounters = counters[numID, default: [:]]
        for existingLevel in numCounters.keys where existingLevel > level {
            numCounters.removeValue(forKey: existingLevel)
        }

        let start = definition.startOverrides[numID]?[level] ?? levelDefinition.start
        if let current = numCounters[level] {
            numCounters[level] = current + 1
        } else {
            numCounters[level] = start
        }
        counters[numID] = numCounters

        if levelDefinition.format == "bullet" {
            let bullet = levelDefinition.text.replacingOccurrences(of: #"%\d+"#, with: "", options: .regularExpression)
            return bullet.isEmpty ? "•" : bullet
        }

        var rendered = levelDefinition.text
        for referencedLevel in 0...8 {
            let token = "%\(referencedLevel + 1)"
            guard rendered.contains(token) else { continue }
            guard let referencedDefinition = definition.abstractLevels[abstractID]?[referencedLevel] else { continue }
            let referencedStart = definition.startOverrides[numID]?[referencedLevel] ?? referencedDefinition.start
            let value = numCounters[referencedLevel] ?? referencedStart
            guard let formatted = format(value, as: referencedDefinition.format) else { return nil }
            rendered = rendered.replacingOccurrences(of: token, with: formatted)
        }

        return rendered.contains("%") ? nil : rendered
    }

    private func format(_ value: Int, as format: String) -> String? {
        switch format {
        case "decimal", "decimalZero":
            return String(value)
        case "lowerLetter":
            return alphabetic(value).lowercased()
        case "upperLetter":
            return alphabetic(value).uppercased()
        case "lowerRoman":
            return roman(value)?.lowercased()
        case "upperRoman":
            return roman(value)
        case "bullet":
            return "•"
        case "none":
            return ""
        default:
            return nil
        }
    }

    private func alphabetic(_ value: Int) -> String {
        guard value > 0 else { return String(value) }
        var number = value
        var result = ""
        while number > 0 {
            number -= 1
            let scalar = UnicodeScalar(65 + (number % 26))!
            result.insert(Character(scalar), at: result.startIndex)
            number /= 26
        }
        return result
    }

    private func roman(_ value: Int) -> String? {
        guard value > 0, value < 4_000 else { return nil }
        let values: [(Int, String)] = [
            (1000, "M"), (900, "CM"), (500, "D"), (400, "CD"),
            (100, "C"), (90, "XC"), (50, "L"), (40, "XL"),
            (10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")
        ]
        var remaining = value
        var result = ""
        for (number, symbol) in values {
            while remaining >= number {
                result += symbol
                remaining -= number
            }
        }
        return result
    }
}
