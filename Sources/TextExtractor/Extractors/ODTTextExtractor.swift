import Foundation
import ZIPFoundation

public struct ODTTextExtractor: TextFormatExtractor {
    private static let mimeType = "application/vnd.oasis.opendocument.text"

    public let format: TextExtractionFormat = .odt
    public let supportedFileExtensions: Set<String> = TextExtractionFormat.odt.fileExtensions

    public init() {}

    public func canExtract(data: Data, fileName: String?) -> Bool {
        if let ext = FileName.fileExtension(from: fileName),
           supportedFileExtensions.contains(ext) {
            return true
        }

        guard data.starts(with: [0x50, 0x4B]) else { return false }

        do {
            let archive = try Archive(data: data, accessMode: .read)
            guard archive["content.xml"] != nil,
                  let mimetypeEntry = archive["mimetype"],
                  mimetypeEntry.type == .file,
                  mimetypeEntry.uncompressedSize <= 256 else {
                return false
            }

            var mimetypeData = Data()
            _ = try archive.extract(mimetypeEntry) { chunk in
                guard mimetypeData.count <= 256 - chunk.count else {
                    throw TextExtractionError.invalidDocument(reason: "ODT mimetype entry is unexpectedly large.")
                }
                mimetypeData.append(chunk)
            }

            let mimetype = String(decoding: mimetypeData, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return mimetype == Self.mimeType
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
        let archive = try ArchiveSupport.openArchive(
            data: data,
            sourceURL: sourceURL,
            formatName: "ODT"
        )
        try ArchiveSupport.validateEntryCount(
            archive,
            options: options,
            formatName: "ODT"
        )

        var budget = ArchiveExtractionBudget(options: options, formatName: "ODT")

        guard let mimetypeData = try ArchiveSupport.readEntry(
            "mimetype",
            in: archive,
            budget: &budget
        ) else {
            throw TextExtractionError.invalidDocument(reason: "Missing ODT mimetype entry.")
        }

        let mimetype = String(decoding: mimetypeData, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard mimetype == Self.mimeType else {
            throw TextExtractionError.invalidDocument(reason: "Unexpected ODT mimetype.")
        }

        guard let contentXML = try ArchiveSupport.readEntry(
            "content.xml",
            in: archive,
            budget: &budget
        ) else {
            throw TextExtractionError.invalidDocument(reason: "Missing ODT content.xml.")
        }

        let blocks: [ODTTextBlock]
        do {
            blocks = try ODTXMLTextParser.parseBlocks(from: contentXML)
        } catch let error as TextExtractionError {
            throw error
        } catch {
            throw TextExtractionError.invalidDocument(reason: "Could not parse ODT content.xml.")
        }

        let paragraphs = blocks.compactMap { block -> String? in
            let normalized = normalizeText(block.text, options: options)
            return normalized.isEmpty ? nil : normalized
        }

        let text = paragraphs
            .joined(separator: options.preserveParagraphs ? options.paragraphSeparator : " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return ExtractedTextDocument(
            title: FileName.title(from: fileName, sourceURL: sourceURL),
            sourceURL: sourceURL,
            format: format,
            text: text,
            metadata: [
                "container": "OpenDocument",
                "mimeType": Self.mimeType,
                "expandedArchiveBytes": String(budget.expandedBytes)
            ]
        )
    }

    private func normalizeText(_ text: String, options: TextExtractionOptions) -> String {
        guard text.contains("\t") else {
            return StringNormalizer.normalize(text, options: options)
        }

        return text
            .components(separatedBy: "\t")
            .map { StringNormalizer.normalize($0, options: options) }
            .joined(separator: "\t")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
