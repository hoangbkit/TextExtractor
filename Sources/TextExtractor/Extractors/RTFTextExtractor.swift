import Foundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

public struct RTFTextExtractor: TextFormatExtractor {
    public let format: TextExtractionFormat = .rtf
    public let supportedFileExtensions: Set<String> = TextExtractionFormat.rtf.fileExtensions
    public init() {}

    public func canExtract(data: Data, fileName: String?) -> Bool {
        guard let ext = FileName.fileExtension(from: fileName) else { return false }
        return supportedFileExtensions.contains(ext)
    }

    public func extract(data: Data, fileName: String?, sourceURL: URL?, options: TextExtractionOptions) throws -> ExtractedTextDocument {
        #if canImport(AppKit) || canImport(UIKit)
        let attributed: NSAttributedString
        do {
            attributed = try NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
            )
        } catch {
            throw TextExtractionError.invalidDocument(reason: "Could not parse RTF document.")
        }
        return ExtractedTextDocument(
            title: FileName.title(from: fileName, sourceURL: sourceURL),
            sourceURL: sourceURL,
            format: format,
            text: StringNormalizer.normalize(attributed.string, options: options),
            rawText: try? StringDecoder.decode(data, fileName: fileName)
        )
        #else
        throw TextExtractionError.unsupportedOnCurrentPlatform(format: .rtf)
        #endif
    }
}
