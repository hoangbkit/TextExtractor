import Foundation

public final class TextExtractor: @unchecked Sendable {
    private let extractors: [any TextFormatExtractor]

    public init(extractors: [any TextFormatExtractor]? = nil) {
        self.extractors = extractors ?? [
            PlainTextExtractor(),
            MarkdownTextExtractor(),
            SRTSubtitleExtractor(),
            VTTSubtitleExtractor(),
            RTFTextExtractor(),
            HTMLTextExtractor(),
            DOCXTextExtractor()
        ]
    }

    public var supportedFormats: [TextExtractionFormat] {
        extractors.map(\.format)
    }

    public var supportedFileExtensions: Set<String> {
        Set(extractors.flatMap { $0.supportedFileExtensions })
    }

    public func extract(from url: URL, options: TextExtractionOptions = TextExtractionOptions()) throws -> ExtractedTextDocument {
        let didAccess = options.startAccessingSecurityScopedResource ? url.startAccessingSecurityScopedResource() : false
        defer {
            if didAccess { url.stopAccessingSecurityScopedResource() }
        }

        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        if values.isRegularFile == false {
            throw TextExtractionError.invalidDocument(reason: "URL is not a regular file.")
        }

        if let size = values.fileSize, size > options.maxInputBytes {
            throw TextExtractionError.fileTooLarge(actualBytes: size, maxBytes: options.maxInputBytes)
        }

        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        return try extract(data: data, fileName: url.lastPathComponent, sourceURL: url, options: options)
    }

    public func extract(data: Data, fileName: String?, options: TextExtractionOptions = TextExtractionOptions()) throws -> ExtractedTextDocument {
        try extract(data: data, fileName: fileName, sourceURL: nil, options: options)
    }

    public func extractor(forFileName fileName: String?, data: Data = Data()) -> (any TextFormatExtractor)? {
        if let ext = FileName.fileExtension(from: fileName) {
            if let match = extractors.first(where: { $0.supportedFileExtensions.contains(ext) }) {
                return match
            }
        }

        return extractors.first { $0.canExtract(data: data, fileName: fileName) }
    }

    private func extract(
        data: Data,
        fileName: String?,
        sourceURL: URL?,
        options: TextExtractionOptions
    ) throws -> ExtractedTextDocument {
        if data.count > options.maxInputBytes {
            throw TextExtractionError.fileTooLarge(actualBytes: data.count, maxBytes: options.maxInputBytes)
        }

        guard let extractor = extractor(forFileName: fileName, data: data) else {
            throw TextExtractionError.unsupportedFileType(fileName: fileName)
        }

        let document = try extractor.extract(data: data, fileName: fileName, sourceURL: sourceURL, options: options)
        guard !document.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !document.segments.isEmpty else {
            throw TextExtractionError.emptyDocument
        }
        return document
    }
}
