import Foundation

public enum TextExtractionFormat: String, CaseIterable, Sendable, Equatable {
    case plainText
    case markdown
    case srt
    case vtt
    case rtf
    case html
    case docx

    public var fileExtensions: Set<String> {
        switch self {
        case .plainText: return ["txt", "text"]
        case .markdown: return ["md", "markdown", "mdown", "mkd"]
        case .srt: return ["srt"]
        case .vtt: return ["vtt", "webvtt"]
        case .rtf: return ["rtf"]
        case .html: return ["html", "htm"]
        case .docx: return ["docx"]
        }
    }
}

public enum MarkdownExtractionMode: Sendable, Equatable {
    /// Keep the original Markdown mostly intact. Useful when another cleaner/LLM handles cleanup.
    case raw

    /// Convert common Markdown syntax into speech-friendly readable text.
    case readableText
}

public struct TextExtractionOptions: Sendable, Equatable {
    public var maxInputBytes: Int
    public var normalizeWhitespace: Bool
    public var preserveParagraphs: Bool
    public var paragraphSeparator: String
    public var startAccessingSecurityScopedResource: Bool

    public var markdownMode: MarkdownExtractionMode
    public var dropMarkdownCodeBlocks: Bool

    public var removeDuplicateSubtitleLines: Bool
    public var subtitleCueSeparator: String

    public var includeDOCXFootnotes: Bool
    public var includeDOCXEndnotes: Bool
    public var includeDOCXHeadersAndFooters: Bool

    /// Maximum uncompressed size of any single archive entry loaded by an archive-backed extractor.
    public var maxArchiveEntryBytes: Int

    /// Maximum cumulative uncompressed bytes loaded from an archive during one extraction.
    public var maxExpandedArchiveBytes: Int

    /// Maximum number of entries accepted in an archive container.
    public var maxArchiveEntryCount: Int

    public init(
        maxInputBytes: Int = 50 * 1024 * 1024,
        normalizeWhitespace: Bool = true,
        preserveParagraphs: Bool = true,
        paragraphSeparator: String = "\n\n",
        startAccessingSecurityScopedResource: Bool = true,
        markdownMode: MarkdownExtractionMode = .readableText,
        dropMarkdownCodeBlocks: Bool = true,
        removeDuplicateSubtitleLines: Bool = true,
        subtitleCueSeparator: String = "\n",
        includeDOCXFootnotes: Bool = true,
        includeDOCXEndnotes: Bool = true,
        includeDOCXHeadersAndFooters: Bool = false,
        maxArchiveEntryBytes: Int = 64 * 1024 * 1024,
        maxExpandedArchiveBytes: Int = 128 * 1024 * 1024,
        maxArchiveEntryCount: Int = 2_048
    ) {
        self.maxInputBytes = maxInputBytes
        self.normalizeWhitespace = normalizeWhitespace
        self.preserveParagraphs = preserveParagraphs
        self.paragraphSeparator = paragraphSeparator
        self.startAccessingSecurityScopedResource = startAccessingSecurityScopedResource
        self.markdownMode = markdownMode
        self.dropMarkdownCodeBlocks = dropMarkdownCodeBlocks
        self.removeDuplicateSubtitleLines = removeDuplicateSubtitleLines
        self.subtitleCueSeparator = subtitleCueSeparator
        self.includeDOCXFootnotes = includeDOCXFootnotes
        self.includeDOCXEndnotes = includeDOCXEndnotes
        self.includeDOCXHeadersAndFooters = includeDOCXHeadersAndFooters
        self.maxArchiveEntryBytes = maxArchiveEntryBytes
        self.maxExpandedArchiveBytes = maxExpandedArchiveBytes
        self.maxArchiveEntryCount = maxArchiveEntryCount
    }
}

public struct ExtractedTextSegment: Sendable, Equatable, Identifiable {
    public var id: String
    public var text: String
    public var startTime: TimeInterval?
    public var endTime: TimeInterval?
    public var metadata: [String: String]

    public init(
        id: String,
        text: String,
        startTime: TimeInterval? = nil,
        endTime: TimeInterval? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
        self.metadata = metadata
    }
}

public struct TextExtractionWarning: Sendable, Equatable, CustomStringConvertible {
    public var message: String

    public init(_ message: String) {
        self.message = message
    }

    public var description: String { message }
}

public struct ExtractedTextDocument: Sendable, Equatable {
    public var title: String
    public var sourceURL: URL?
    public var format: TextExtractionFormat
    public var text: String
    public var segments: [ExtractedTextSegment]
    public var metadata: [String: String]
    public var warnings: [TextExtractionWarning]

    public init(
        title: String,
        sourceURL: URL? = nil,
        format: TextExtractionFormat,
        text: String,
        segments: [ExtractedTextSegment] = [],
        metadata: [String: String] = [:],
        warnings: [TextExtractionWarning] = []
    ) {
        self.title = title
        self.sourceURL = sourceURL
        self.format = format
        self.text = text
        self.segments = segments
        self.metadata = metadata
        self.warnings = warnings
    }
}

public enum TextExtractionError: Error, Sendable, Equatable, LocalizedError {
    case unsupportedFileType(fileName: String?)
    case fileTooLarge(actualBytes: Int, maxBytes: Int)
    case emptyDocument
    case unreadableTextEncoding(fileName: String?)
    case invalidDocument(reason: String)
    case unsupportedOnCurrentPlatform(format: TextExtractionFormat)

    public var errorDescription: String? {
        switch self {
        case .unsupportedFileType(let fileName):
            return "Unsupported file type: \(fileName ?? "unknown")"
        case .fileTooLarge(let actualBytes, let maxBytes):
            return "File is too large: \(actualBytes) bytes, max: \(maxBytes) bytes"
        case .emptyDocument:
            return "The document did not contain readable text."
        case .unreadableTextEncoding(let fileName):
            return "Could not decode text encoding for \(fileName ?? "document")."
        case .invalidDocument(let reason):
            return "Invalid document: \(reason)"
        case .unsupportedOnCurrentPlatform(let format):
            return "\(format.rawValue) extraction is unsupported on this platform."
        }
    }
}

public protocol TextFormatExtractor: Sendable {
    var format: TextExtractionFormat { get }
    var supportedFileExtensions: Set<String> { get }

    func canExtract(data: Data, fileName: String?) -> Bool

    func extract(
        data: Data,
        fileName: String?,
        sourceURL: URL?,
        options: TextExtractionOptions
    ) throws -> ExtractedTextDocument
}
