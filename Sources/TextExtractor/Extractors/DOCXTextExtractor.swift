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

        // ZIP local file header. A DOCX is an OOXML ZIP package.
        return data.starts(with: [0x50, 0x4B, 0x03, 0x04])
    }

    public func extract(
        data: Data,
        fileName: String?,
        sourceURL: URL?,
        options: TextExtractionOptions
    ) throws -> ExtractedTextDocument {
        let url = try materializeArchiveURL(data: data, sourceURL: sourceURL)
        let shouldDelete = sourceURL == nil
        defer {
            if shouldDelete { try? FileManager.default.removeItem(at: url) }
        }

        guard let archive = Archive(url: url, accessMode: .read) else {
            throw TextExtractionError.invalidDocument(reason: "Could not open DOCX ZIP archive.")
        }

        guard let documentXML = try readEntry("word/document.xml", in: archive) else {
            throw TextExtractionError.invalidDocument(reason: "Missing word/document.xml.")
        }

        var paragraphs: [String] = []
        var warnings: [TextExtractionWarning] = []

        do {
            paragraphs.append(contentsOf: try DOCXXMLTextParser.parseParagraphs(from: documentXML))
        } catch {
            throw TextExtractionError.invalidDocument(reason: "Could not parse word/document.xml: \(error.localizedDescription)")
        }

        if options.includeDOCXFootnotes, let footnotes = try readEntry("word/footnotes.xml", in: archive) {
            do {
                let footnoteText = try DOCXXMLTextParser.parseParagraphs(from: footnotes)
                if !footnoteText.isEmpty {
                    paragraphs.append(contentsOf: footnoteText)
                }
            } catch {
                warnings.append(TextExtractionWarning("Could not parse DOCX footnotes."))
            }
        }

        if options.includeDOCXEndnotes, let endnotes = try readEntry("word/endnotes.xml", in: archive) {
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
                guard let data = try readEntry(entry.path, in: archive) else { continue }
                do {
                    paragraphs.append(contentsOf: try DOCXXMLTextParser.parseParagraphs(from: data))
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
            metadata: ["container": "OOXML"],
            warnings: warnings
        )
    }

    private func materializeArchiveURL(data: Data, sourceURL: URL?) throws -> URL {
        if let sourceURL { return sourceURL }

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "TextExtractor-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("document.docx")
        try data.write(to: url, options: [.atomic])
        return url
    }

    private func readEntry(_ path: String, in archive: Archive) throws -> Data? {
        guard let entry = archive[path] else { return nil }
        var data = Data()
        _ = try archive.extract(entry) { chunk in
            data.append(chunk)
        }
        return data
    }
}
