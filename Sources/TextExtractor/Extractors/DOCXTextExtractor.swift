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
        let archive = try openArchive(data: data, sourceURL: sourceURL)
        try validateArchiveEntryCount(archive, options: options)
        var budget = DOCXArchiveBudget(options: options)
        var warnings: [TextExtractionWarning] = []

        guard let documentXML = try readEntry("word/document.xml", in: archive, budget: &budget) else {
            throw TextExtractionError.invalidDocument(reason: "Missing word/document.xml.")
        }

        let bodyBlocks: [DOCXTextBlock]
        do {
            bodyBlocks = try DOCXXMLTextParser.parseBlocks(from: documentXML)
        } catch {
            throw TextExtractionError.invalidDocument(reason: "Could not parse word/document.xml.")
        }

        var numberingDefinition: DOCXNumberingDefinition?
        if let numberingXML = try readEntry("word/numbering.xml", in: archive, budget: &budget) {
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
           let footnotesXML = try readEntry("word/footnotes.xml", in: archive, budget: &budget) {
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
           let endnotesXML = try readEntry("word/endnotes.xml", in: archive, budget: &budget) {
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
                guard let partData = try readEntry(path, in: archive, budget: &budget) else { continue }
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

    private func openArchive(data: Data, sourceURL: URL?) throws -> Archive {
        do {
            if let sourceURL { return try Archive(url: sourceURL, accessMode: .read) }
            return try Archive(data: data, accessMode: .read)
        } catch { throw TextExtractionError.invalidDocument(reason: "Could not open DOCX ZIP archive.") }
    }

    private func validateArchiveEntryCount(_ archive: Archive, options: TextExtractionOptions) throws {
        let maxCount = max(0, options.maxArchiveEntryCount)
        var count = 0
        for _ in archive {
            count += 1
            if count > maxCount {
                throw TextExtractionError.invalidDocument(reason: "DOCX archive entry count exceeds maxArchiveEntryCount (\(maxCount)).")
            }
        }
    }

    private func readEntry(_ path: String, in archive: Archive, budget: inout DOCXArchiveBudget) throws -> Data? {
        guard let entry = archive[path] else { return nil }
        guard entry.type == .file else {
            throw TextExtractionError.invalidDocument(reason: "DOCX archive entry is not a regular file: \(path).")
        }
        return try budget.extract(entry, from: archive)
    }
}

private struct DOCXArchiveBudget {
    let maxEntryBytes: UInt64
    let maxExpandedBytes: UInt64
    private(set) var expandedBytes: UInt64 = 0

    init(options: TextExtractionOptions) {
        maxEntryBytes = UInt64(max(0, options.maxArchiveEntryBytes))
        maxExpandedBytes = UInt64(max(0, options.maxExpandedArchiveBytes))
    }

    mutating func extract(_ entry: Entry, from archive: Archive) throws -> Data {
        guard entry.uncompressedSize <= maxEntryBytes else {
            throw TextExtractionError.invalidDocument(reason: "DOCX archive entry exceeds maxArchiveEntryBytes: \(entry.path) expands to \(entry.uncompressedSize) bytes, max \(maxEntryBytes).")
        }
        guard expandedBytes <= maxExpandedBytes, entry.uncompressedSize <= maxExpandedBytes - expandedBytes else {
            throw TextExtractionError.invalidDocument(reason: "DOCX expanded content exceeds maxExpandedArchiveBytes (\(maxExpandedBytes)).")
        }

        let remainingExpandedBytes = maxExpandedBytes - expandedBytes
        var actualEntryBytes: UInt64 = 0
        var data = Data()
        do {
            _ = try archive.extract(entry) { chunk in
                let chunkBytes = UInt64(chunk.count)
                guard actualEntryBytes <= UInt64.max - chunkBytes else {
                    throw TextExtractionError.invalidDocument(reason: "DOCX archive entry size overflow: \(entry.path).")
                }
                actualEntryBytes += chunkBytes
                guard actualEntryBytes <= maxEntryBytes else {
                    throw TextExtractionError.invalidDocument(reason: "DOCX archive entry exceeds maxArchiveEntryBytes while extracting: \(entry.path).")
                }
                guard actualEntryBytes <= remainingExpandedBytes else {
                    throw TextExtractionError.invalidDocument(reason: "DOCX expanded content exceeds maxExpandedArchiveBytes while extracting.")
                }
                data.append(chunk)
            }
        } catch let error as TextExtractionError {
            throw error
        } catch {
            throw TextExtractionError.invalidDocument(reason: "Could not extract DOCX archive entry: \(entry.path).")
        }
        expandedBytes += actualEntryBytes
        return data
    }
}
