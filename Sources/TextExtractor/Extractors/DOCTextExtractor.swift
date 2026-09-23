import Foundation
#if canImport(AppKit)
import AppKit
#endif

public struct DOCTextExtractor: TextFormatExtractor {
    public let format: TextExtractionFormat = .doc
    public let supportedFileExtensions: Set<String> = TextExtractionFormat.doc.fileExtensions

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
        #if canImport(AppKit)
        let attributed: NSAttributedString
        do {
            attributed = try NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.docFormat],
                documentAttributes: nil
            )
        } catch {
            throw TextExtractionError.invalidDocument(reason: "Could not parse legacy Microsoft Word document.")
        }

        return ExtractedTextDocument(
            title: FileName.title(from: fileName, sourceURL: sourceURL),
            sourceURL: sourceURL,
            format: format,
            text: StringNormalizer.normalize(attributed.string, options: options),
            metadata: [
                "container": "Microsoft Word Binary",
                "importer": "NSAttributedString.docFormat"
            ]
        )
        #else
        throw TextExtractionError.unsupportedOnCurrentPlatform(format: .doc)
        #endif
    }
}
