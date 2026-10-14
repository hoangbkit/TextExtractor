import Foundation

/// The semantic role of a logical article block, independent of text-to-speech
/// chunk sizes or any reading preference.
public enum WebArticleBlockKind: Hashable, Codable, Sendable {
    case paragraph
    case heading(level: Int)
    case listItem
    case quote
    case code
    case table
    case caption
    /// Source text whose structure cannot safely be established.
    case preservedContent
}

/// Errors raised when constructing or decoding an invalid typed result.
///
/// Parser failures (such as an unreadable article) are a separate concern.
public enum WebArticleModelError: Error, Equatable, Sendable {
    case emptyBlockIdentifier
    case emptyBlockText
    case invalidHeadingLevel(Int)
    case emptyTitle
    case emptyBlocks
    case duplicateBlockIdentifier(String)
}

/// A single logical article unit, in source reading order.
///
/// IDs are unique within their article, including blocks with equal visible
/// text. The extractor will assign deterministic, occurrence-based IDs; clients
/// must not treat IDs as permanent across changed HTML or changed segmentation.
public struct WebArticleBlock: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let kind: WebArticleBlockKind
    public let text: String

    public init(id: String, kind: WebArticleBlockKind, text: String) throws {
        guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw WebArticleModelError.emptyBlockIdentifier
        }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw WebArticleModelError.emptyBlockText
        }
        if case .heading(let level) = kind, !(1...6).contains(level) {
            throw WebArticleModelError.invalidHeadingLevel(level)
        }
        self.id = id
        self.kind = kind
        self.text = text
    }

    private enum CodingKeys: String, CodingKey {
        case id, kind, text
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: values.decode(String.self, forKey: .id),
            kind: values.decode(WebArticleBlockKind.self, forKey: .kind),
            text: values.decode(String.self, forKey: .text)
        )
    }
}

/// Pure rendering of already-normalized blocks. Does not classify, join, or
/// re-normalize source content. A separate paragraph separator never implies a
/// speech chunk boundary.
public enum WebArticleTextRenderer {
    public static let blockSeparator = "\n\n"

    public static func render(_ blocks: [WebArticleBlock]) -> String {
        blocks.map(\.text).joined(separator: blockSeparator)
    }
}

/// A standalone, typed article value.
///
/// The authoritative representation is `blocks`. `text` is computed from
/// those blocks so the two cannot diverge. Existing TextExtractor data models
/// are deliberately not extended or modified.
public struct WebArticleResult: Hashable, Codable, Sendable {
    public let title: String
    public let sourceURL: URL
    public let blocks: [WebArticleBlock]
    /// Known keys: author, siteName, language, publishedTime. Unknown additional
    /// keys may be carried without implying a value was inferred.
    public let metadata: [String: String]

    public var text: String {
        WebArticleTextRenderer.render(blocks)
    }

    public init(
        title: String,
        sourceURL: URL,
        blocks: [WebArticleBlock],
        metadata: [String: String] = [:]
    ) throws {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw WebArticleModelError.emptyTitle
        }
        guard !blocks.isEmpty else {
            throw WebArticleModelError.emptyBlocks
        }
        var seenIDs = Set<String>()
        for block in blocks {
            guard seenIDs.insert(block.id).inserted else {
                throw WebArticleModelError.duplicateBlockIdentifier(block.id)
            }
        }
        self.title = trimmedTitle
        self.sourceURL = sourceURL
        self.blocks = blocks
        self.metadata = metadata
    }

    private enum CodingKeys: String, CodingKey {
        case title, sourceURL, blocks, metadata
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            title: values.decode(String.self, forKey: .title),
            sourceURL: values.decode(URL.self, forKey: .sourceURL),
            blocks: values.decode([WebArticleBlock].self, forKey: .blocks),
            metadata: values.decodeIfPresent([String: String].self, forKey: .metadata) ?? [:]
        )
    }
}
