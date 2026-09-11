import Foundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

public struct HTMLTextExtractor: TextFormatExtractor {
    public let format: TextExtractionFormat = .html
    public let supportedFileExtensions: Set<String> = TextExtractionFormat.html.fileExtensions

    private static let blockBoundaryMarker = "\u{E000}TEXTEXTRACTOR_BLOCK_BOUNDARY\u{E001}"

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
        let markedData: Data
        if let html = try? StringDecoder.decode(data, fileName: fileName) {
            let markedHTML = BasicHTMLTextExtractor.insertingBlockBoundaryMarkers(
                in: html,
                marker: Self.blockBoundaryMarker
            )
            markedData = Data(markedHTML.utf8)
        } else {
            markedData = data
        }

        if let attributed = try? NSAttributedString(
            data: markedData,
            options: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ],
            documentAttributes: nil
        ) {
            let separator = options.preserveParagraphs ? options.paragraphSeparator : "\n"
            let structured = Self.replacingBlockBoundaryMarkers(
                in: attributed.string,
                with: separator
            )
            text = StringNormalizer.normalize(structured, options: options)
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

    private static func replacingBlockBoundaryMarkers(in text: String, with separator: String) -> String {
        var output = text

        while let markerRange = output.range(of: blockBoundaryMarker) {
            var lowerBound = markerRange.lowerBound
            while lowerBound > output.startIndex {
                let previous = output.index(before: lowerBound)
                guard isBoundaryWhitespace(output[previous]) else { break }
                lowerBound = previous
            }

            var upperBound = markerRange.upperBound
            while upperBound < output.endIndex {
                guard isBoundaryWhitespace(output[upperBound]) else { break }
                upperBound = output.index(after: upperBound)
            }

            output.replaceSubrange(lowerBound..<upperBound, with: separator)
        }

        return output
    }

    private static func isBoundaryWhitespace(_ character: Character) -> Bool {
        character == " " || character == "\t" || character == "\n" || character == "\r"
    }
}
