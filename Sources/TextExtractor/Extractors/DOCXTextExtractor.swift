import Foundation
import ZIPFoundation

public struct DOCXTextExtractor: TextFormatExtractor {
    public let format: TextExtractionFormat = .docx
    public let supportedFileExtensions: Set<String> = TextExtractionFormat.docx.fileExtensions

    public init() {}

    public func canExtract(data: Data, fileName: String?) -> Bool {
        if let ext = FileName.fileExtension(from: fileName), supportedFileExtensions.contains(ext) {
            return true
        }

        guard data.starts(with: [0x50, 0x4B]) else { return false }

        do {
            let archive = try Archive(data: data, accessMode: .read)
            return archive["word/document.xml"] != nil
        } catch {
            return false
        }
    }

    public func extract(
        data: Data,
        fileName: String?,
        sourceURL: URL?,
        options: TextExtractionOptions
    ) throws -> ExtractedTextDocument {
        let archive = try openArchive(data: data, sourceURL: sourceURL)
        try validateArchiveEntryCount(archive, options: options)

        var budget = DOCXArchiveBudget(options: options)
        guard let documentXML = try readEntry("word/document.xml", in: archive, budget: &budget) else {
            throw TextExtractionError.invalidDocument(reason: "Missing word/document.xml.")
        }

        var paragraphs: [String] = []
        var warnings: [TextExtractionWarning] = []

        do {
            paragraphs.append(contentsOf: try DOCXXMLTextParser.parseParagraphs(from: documentXML))
        } catch {
            throw TextExtractionError.invalidDocument(reason: "Could not parse word/document.xml: \(error.localizedDescription)")
        }

        if options.includeDOCXFootnotes,
           let footnotes = try readEntry("word/footnotes.xml", in: archive, budget: &budget) {
            do {
                let footnoteText = try DOCXXMLTextParser.parseParagraphs(from: footnotes)
                if !footnoteText.isEmpty {
                    paragraphs.append(contentsOf: footnoteText)
                }
            } catch {
                warnings.append(TextExtractionWarning("Could not parse DOCX footnotes."))
            }
        }

        if options.includeDOCXEndnotes,
           let endnotes = try readEntry("word/endnotes.xml", in: archive, budget: &budget) {
            do {
                let endnoteText = try DOCXXMLTextParser.parseParagraphs(from: endnotes)
                if !endnoteText.isEmpty {
                    paragraphs.append(contentsOf: endnoteText)
                }
            } catch {
                warnings.append(TextExtractionWarning("Could not parse DOCX endnotes."))
            }
        }

        if options.includeDOCXHeadersAndFooters {
            for entry in archive {
                let path = entry.path.lowercased()
                guard path.hasPrefix("word/header") || path.hasPrefix("word/footer") else { continue }
                guard let entryData = try readEntry(entry.path, in: archive, budget: &budget) else { continue }
                do {
                    paragraphs.append(contentsOf: try DOCXXMLTextParser.parseParagraphs(from: entryData))
                } catch {
                    warnings.append(TextExtractionWarning("Could not parse \(entry.path)."))
                }
            }
        }

        var text = StringNormalizer.joinParagraphs(paragraphs, separator: options.paragraphSeparator)
        text = StringNormalizer.normalize(text, options: options)

        return ExtractedTextDocument(
            title: FileName.title(from: fileName, sourceURL: sourceURL),
            sourceURL: sourceURL,
            format: format,
            text: text,
            metadata: [
                "container": "OOXML",
                "expandedArchiveBytes": String(budget.expandedBytes)
            ],
            warnings: warnings
        )
    }

    private func openArchive(data: Data, sourceURL: URL?) throws -> Archive {
        do {
            if let sourceURL {
                return try Archive(url: sourceURL, accessMode: .read)
            }
            return try Archive(data: data, accessMode: .read)
        } catch {
            throw TextExtractionError.invalidDocument(reason: "Could not open DOCX ZIP archive.")
        }
    }

    private func validateArchiveEntryCount(_ archive: Archive, options: TextExtractionOptions) throws {
        let maxCount = max(0, options.maxArchiveEntryCount)
        var count = 0

        for _ in archive {
            count += 1
            if count > maxCount {
                throw TextExtractionError.invalidDocument(
                    reason: "DOCX archive entry count exceeds maxArchiveEntryCount (\(maxCount))."
                )
            }
        }
    }

    private func readEntry(
        _ path: String,
        in archive: Archive,
        budget: inout DOCXArchiveBudget
    ) throws -> Data? {
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
            throw TextExtractionError.invalidDocument(
                reason: "DOCX archive entry exceeds maxArchiveEntryBytes: \(entry.path) expands to \(entry.uncompressedSize) bytes, max \(maxEntryBytes)."
            )
        }

        guard expandedBytes <= maxExpandedBytes,
              entry.uncompressedSize <= maxExpandedBytes - expandedBytes else {
            throw TextExtractionError.invalidDocument(
                reason: "DOCX expanded content exceeds maxExpandedArchiveBytes (\(maxExpandedBytes))."
            )
        }

        let remainingExpandedBytes = maxExpandedBytes - expandedBytes
        var actualEntryBytes: UInt64 = 0
        var data = Data()

        _ = try archive.extract(entry) { chunk in
            let chunkBytes = UInt64(chunk.count)
            guard actualEntryBytes <= UInt64.max - chunkBytes else {
                throw TextExtractionError.invalidDocument(reason: "DOCX archive entry size overflow: \(entry.path).")
            }

            actualEntryBytes += chunkBytes

            guard actualEntryBytes <= maxEntryBytes else {
                throw TextExtractionError.invalidDocument(
                    reason: "DOCX archive entry exceeds maxArchiveEntryBytes while extracting: \(entry.path)."
                )
            }

            guard actualEntryBytes <= remainingExpandedBytes else {
                throw TextExtractionError.invalidDocument(
                    reason: "DOCX expanded content exceeds maxExpandedArchiveBytes while extracting."
                )
            }

            data.append(chunk)
        }

        expandedBytes += actualEntryBytes
        return data
    }
}
