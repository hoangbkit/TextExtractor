import Foundation
import ZIPFoundation

public struct DOCXTextExtractor: TextFormatExtractor {
    public let format: TextExtractionFormat = .docx
    public let supportedFileExtensions: Set<String> = TextExtractionFormat.docx.fileExtensions
    public init() {}

    public func canExtract(data: Data, fileName: String?) -> Bool {
        if let ext = FileName.fileExtension(from: fileName), supportedFileExtensions.contains(ext) { return true }
        guard data.starts(with: [0x50, 0x4B]) else { return false }
        do {
            let archive = try Archive(data: data, accessMode: .read)
            return archive["word/document.xml"] != nil
        } catch { return false }
    }

    public func extract(data: Data, fileName: String?, sourceURL: URL?, options: TextExtractionOptions) throws -> ExtractedTextDocument {
        let archive = try ArchiveSupport.openArchive(data: data, sourceURL: sourceURL, formatName: "DOCX")
        try ArchiveSupport.validateEntryCount(archive, options: options, formatName: "DOCX")
        var budget = ArchiveExtractionBudget(options: options, formatName: "DOCX")
        var warnings: [TextExtractionWarning] = []

        guard let documentXML = try ArchiveSupport.readEntry("word/document.xml", in: archive, budget: &budget) else {
            throw TextExtractionError.invalidDocument(reason: "Missing word/document.xml.")
        }

        let bodyBlocks: [DOCXTextBlock]
        do {
            bodyBlocks = try DOCXXMLTextParser.parseBlocks(from: documentXML)
        } catch {
            throw TextExtractionError.invalidDocument(reason: "Could not parse word/document.xml.")
        }

        var numberingDefinition: DOCXNumberingDefinition?
        if let numberingXML = try ArchiveSupport.readEntry("word/numbering.xml", in: archive, budget: &budget) {
            do {
                numberingDefinition = try DOCXNumberingParser.parse(from: numberingXML)
            } catch {
                warnings.append(
                    TextExtractionWarning(
                        code: .unsupportedDOCXFeature,
                        message: "Could not parse DOCX numbering definitions; list text was preserved without generated labels."
                    )
                )
            }
        }

        var numberingResolver = numberingDefinition.map(DOCXNumberingResolver.init)
        var warnedUnsupportedNumbering = false
        var paragraphs = renderBlocks(
            bodyBlocks,
            numberingResolver: &numberingResolver,
            options: options,
            warnings: &warnings,
            warnedUnsupportedNumbering: &warnedUnsupportedNumbering
        )

        var footnoteParagraphCount = 0
        if options.includeDOCXFootnotes,
           let footnotesXML = try ArchiveSupport.readEntry("word/footnotes.xml", in: archive, budget: &budget) {
            do {
                let rendered = renderSupplementalBlocks(try DOCXXMLTextParser.parseBlocks(from: footnotesXML), options: options)
                footnoteParagraphCount = rendered.count
                paragraphs.append(contentsOf: rendered)
            } catch {
                warnings.append(TextExtractionWarning(code: .skippedDOCXFootnotes, message: "Could not parse DOCX footnotes."))
            }
        }

        var endnoteParagraphCount = 0
        if options.includeDOCXEndnotes,
           let endnotesXML = try ArchiveSupport.readEntry("word/endnotes.xml", in: archive, budget: &budget) {
            do {
                let rendered = renderSupplementalBlocks(try DOCXXMLTextParser.parseBlocks(from: endnotesXML), options: options)
                endnoteParagraphCount = rendered.count
                paragraphs.append(contentsOf: rendered)
            } catch {
                warnings.append(TextExtractionWarning(code: .skippedDOCXEndnotes, message: "Could not parse DOCX endnotes."))
            }
        }

        var headerFooterParagraphCount = 0
        if options.includeDOCXHeadersAndFooters {
            var seenHeaderFooterText = Set<String>()
            let paths = archive
                .map(\.path)
                .filter {
                    let path = $0.lowercased()
                    return path.hasPrefix("word/header") || path.hasPrefix("word/footer")
                }
                .sorted()

            for path in paths {
                guard let partData = try ArchiveSupport.readEntry(path, in: archive, budget: &budget) else { continue }
                do {
                    let rendered = renderSupplementalBlocks(try DOCXXMLTextParser.parseBlocks(from: partData), options: options)
                    for paragraph in rendered where seenHeaderFooterText.insert(paragraph).inserted {
                        paragraphs.append(paragraph)
                        headerFooterParagraphCount += 1
                    }
                } catch {
                    let code: TextExtractionWarning.Code = path.lowercased().hasPrefix("word/header") ? .skippedDOCXHeader : .skippedDOCXFooter
                    warnings.append(TextExtractionWarning(code: code, message: "Could not parse \(path)."))
                }
            }
        }

        let text = paragraphs.joined(separator: options.preserveParagraphs ? options.paragraphSeparator : " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return ExtractedTextDocument(
            title: FileName.title(from: fileName, sourceURL: sourceURL),
            sourceURL: sourceURL,
            format: format,
            text: text,
            metadata: [
                "container": "OOXML",
                "expandedArchiveBytes": String(budget.expandedBytes),
                "footnoteParagraphs": String(footnoteParagraphCount),
                "endnoteParagraphs": String(endnoteParagraphCount),
                "headerFooterParagraphs": String(headerFooterParagraphCount)
            ],
            warnings: warnings
        )
    }

    private func renderBlocks(
        _ blocks: [DOCXTextBlock],
        numberingResolver: inout DOCXNumberingResolver?,
        options: TextExtractionOptions,
        warnings: inout [TextExtractionWarning],
        warnedUnsupportedNumbering: inout Bool
    ) -> [String] {
        blocks.compactMap { block in
            var text = block.text
            if let numID = block.numberingID {
                let level = block.numberingLevel ?? 0
                if let label = numberingResolver?.label(numID: numID, level: level), !label.isEmpty {
                    text = "\(label) \(text)"
                } else if numberingResolver != nil && !warnedUnsupportedNumbering {
                    warnings.append(
                        TextExtractionWarning(
                            code: .unsupportedDOCXFeature,
                            message: "One or more DOCX list labels use unsupported or missing numbering definitions; paragraph text was preserved."
                        )
                    )
                    warnedUnsupportedNumbering = true
                }
            }
            let normalized = normalizeDOCXText(text, options: options)
            return normalized.isEmpty ? nil : normalized
        }
    }

    private func renderSupplementalBlocks(_ blocks: [DOCXTextBlock], options: TextExtractionOptions) -> [String] {
        blocks.compactMap { block in
            let normalized = normalizeDOCXText(block.text, options: options)
            return normalized.isEmpty ? nil : normalized
        }
    }

    private func normalizeDOCXText(_ text: String, options: TextExtractionOptions) -> String {
        guard text.contains("\t") else { return StringNormalizer.normalize(text, options: options) }
        return text
            .components(separatedBy: "\t")
            .map { StringNormalizer.normalize($0, options: options) }
            .joined(separator: "\t")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
