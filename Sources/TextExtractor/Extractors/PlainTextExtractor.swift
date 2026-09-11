import Foundation

public struct PlainTextExtractor: TextFormatExtractor {
    public let format: TextExtractionFormat = .plainText
    public let supportedFileExtensions: Set<String> = TextExtractionFormat.plainText.fileExtensions
    public init() {}

    public func canExtract(data: Data, fileName: String?) -> Bool {
        guard let ext = FileName.fileExtension(from: fileName) else { return false }
        return supportedFileExtensions.contains(ext)
    }

    public func extract(data: Data, fileName: String?, sourceURL: URL?, options: TextExtractionOptions) throws -> ExtractedTextDocument {
        let decoded = try StringDecoder.decodeWithEncoding(data, fileName: fileName)
        let warnings: [TextExtractionWarning] = decoded.usedLegacyFallback
            ? [TextExtractionWarning(code: .lossyEncodingFallback, message: "Decoded text using legacy encoding \(decoded.encodingName).")]
            : []
        return ExtractedTextDocument(
            title: FileName.title(from: fileName, sourceURL: sourceURL),
            sourceURL: sourceURL,
            format: format,
            text: StringNormalizer.normalize(decoded.string, options: options),
            rawText: decoded.string,
            metadata: ["encoding": decoded.encodingName],
            warnings: warnings
        )
    }
}
