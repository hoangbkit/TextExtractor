import Foundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

public struct HTMLTextExtractor: TextFormatExtractor {
    public let format: TextExtractionFormat = .html
    public let supportedFileExtensions: Set<String> = TextExtractionFormat.html.fileExtensions

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
        let text: String

        #if canImport(AppKit) || canImport(UIKit)
        if let attributed = try? NSAttributedString(
            data: data,
            options: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ],
            documentAttributes: nil
        ) {
            text = StringNormalizer.normalize(attributed.string, options: options)
        } else {
            text = try BasicHTMLTextExtractor.extractText(from: data, fileName: fileName, options: options)
        }
        #else
        text = try BasicHTMLTextExtractor.extractText(from: data, fileName: fileName, options: options)
        #endif

        return ExtractedTextDocument(
            title: FileName.title(from: fileName, sourceURL: sourceURL),
            sourceURL: sourceURL,
            format: format,
            text: text
        )
    }
}
