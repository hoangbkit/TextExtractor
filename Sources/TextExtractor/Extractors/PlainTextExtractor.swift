import Foundation

public struct PlainTextExtractor: TextFormatExtractor {
    public let format: TextExtractionFormat = .plainText
    public let supportedFileExtensions: Set<String> = TextExtractionFormat.plainText.fileExtensions

    public init() {}

    public func canExtract(data: Data, fileName: String?) -> Bool {
        guard let ext = FileName.fileExtension(from: fileName) else { return false }
        return supportedFileExtensions.contains(ext)
    }

    public func extract(
        data: Data,
        fileName: String?,
        sourceURL: URL?,
        options: TextExtractionOptions
    ) throws -> ExtractedTextDocument {
        let decoded = try StringDecoder.decode(data, fileName: fileName)
        let text = StringNormalizer.normalize(decoded, options: options)

        return ExtractedTextDocument(
            title: FileName.title(from: fileName, sourceURL: sourceURL),
            sourceURL: sourceURL,
            format: format,
            text: text,
            metadata: ["encoding": "auto"]
        )
    }
}
