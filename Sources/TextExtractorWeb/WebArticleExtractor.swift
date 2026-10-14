import Foundation
import SwiftReadability
import SwiftSoup

/// Bounded, offline extraction configuration. Caller is responsible for HTML
/// downloading, redirects, authentication, and any URL security policy.
public struct WebArticleExtractionOptions: Sendable, Equatable {
    public var maxInputBytes: Int
    public var minimumReadableCharacterCount: Int
    public var maxBlocks: Int
    public var maxDOMDepth: Int
    public var maxDOMElements: Int

    public init(
        maxInputBytes: Int = 5 * 1024 * 1024,
        minimumReadableCharacterCount: Int = 40,
        maxBlocks: Int = 10_000,
        maxDOMDepth: Int = 128,
        maxDOMElements: Int = 50_000
    ) {
        self.maxInputBytes = max(0, maxInputBytes)
        self.minimumReadableCharacterCount = max(1, minimumReadableCharacterCount)
        self.maxBlocks = max(1, maxBlocks)
        self.maxDOMDepth = max(1, maxDOMDepth)
        self.maxDOMElements = max(1, maxDOMElements)
    }
}

public enum WebArticleExtractionError: Error, Equatable, Sendable {
    case invalidSourceURL
    case inputTooLarge(actualBytes: Int, maxBytes: Int)
    case unreadableEncoding
    case unreadableArticle
    case tooManyBlocks(maxBlocks: Int)
    case domTooDeep(maxDepth: Int)
}

/// Extracts a typed article from caller-supplied HTML without network I/O.
///
/// SwiftReadability and SwiftSoup are used only within the synchronous call.
/// Neither their mutable DOM nor the non-Sendable Readability parser escapes
/// this boundary. Invoke extraction off the main actor for large inputs.
public struct WebArticleExtractor: Sendable {
    public init() {}

    public func extract(
        html data: Data,
        sourceURL: URL,
        options: WebArticleExtractionOptions = .init()
    ) throws -> WebArticleResult {
        try Task.checkCancellation()
        guard (sourceURL.scheme?.lowercased() == "https" ||
               sourceURL.scheme?.lowercased() == "http"),
              let host = sourceURL.host, !host.isEmpty else {
            throw WebArticleExtractionError.invalidSourceURL
        }
        guard data.count <= options.maxInputBytes else {
            throw WebArticleExtractionError.inputTooLarge(
                actualBytes: data.count, maxBytes: options.maxInputBytes
            )
        }
        let html = try Self.decode(data)
        try Task.checkCancellation()

        // Do not add a text-only fallback: that can narrate navigation or ads
        // on pages without an actual article.
        let reader = Readability(
            html: html,
            url: sourceURL,
            options: ReadabilityOptions(maxElemsToParse: options.maxDOMElements)
        )
        let parsed = try? reader.parse()
        try Task.checkCancellation()
        guard let article = parsed else {
            throw WebArticleExtractionError.unreadableArticle
        }
        try Task.checkCancellation()

        guard let document = try? SwiftSoup.parseBodyFragment(article.contentHTML) else {
            throw WebArticleExtractionError.unreadableArticle
        }
        var collector = WebArticleBlockCollector(options: options)
        if let body = document.body() {
            try collector.collect(body)
        }
        try Task.checkCancellation()
        var drafts = collector.blocks

        let extractedTitle = Self.nonempty(article.title) ?? host
        // Some Readability variants remove the original h1 from the cleaned
        // body. Preserve a single title heading when none survives.
        if !drafts.contains(where: {
            if case .heading(level: 1) = $0.kind { return true }
            return false
        }), Self.nonempty(article.title) != nil {
            drafts.insert(.init(kind: .heading(level: 1), text: extractedTitle), at: 0)
        }

        // A header or title alone cannot establish an article. Count readable
        // body text independently of the title and other metadata.
        let bodyCount = drafts.reduce(0) { count, draft in
            if case .heading = draft.kind { return count }
            return count + draft.text.count
        }
        guard bodyCount >= options.minimumReadableCharacterCount else {
            throw WebArticleExtractionError.unreadableArticle
        }
        guard drafts.count <= options.maxBlocks else {
            throw WebArticleExtractionError.tooManyBlocks(maxBlocks: options.maxBlocks)
        }

        let blocks = try drafts.enumerated().map { index, draft in
            try WebArticleBlock(
                id: String(format: "block-%06d", index + 1),
                kind: draft.kind,
                text: draft.text
            )
        }
        var metadata: [String: String] = [:]
        if let author = Self.nonempty(article.byline) { metadata["author"] = author }
        if let site = Self.nonempty(article.siteName) { metadata["siteName"] = site }
        if let language = Self.nonempty(article.lang) { metadata["language"] = language }
        if let date = Self.nonempty(article.publishedTime) { metadata["publishedTime"] = date }

        try Task.checkCancellation()
        return try WebArticleResult(
            title: extractedTitle,
            sourceURL: sourceURL,
            blocks: blocks,
            metadata: metadata
        )
    }

    private static func nonempty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func decode(_ data: Data) throws -> String {
        guard !data.isEmpty else { throw WebArticleExtractionError.unreadableArticle }
        let bytes = [UInt8](data.prefix(4))
        let text: String?
        if bytes.starts(with: [0xFF, 0xFE]) || bytes.starts(with: [0xFE, 0xFF]) {
            text = String(data: data, encoding: .utf16)
        } else if bytes.starts(with: [0xEF, 0xBB, 0xBF]) {
            text = String(data: data.dropFirst(3), encoding: .utf8)
        } else {
            text = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .windowsCP1252)
        }
        guard let text, !text.contains("\0") else {
            throw WebArticleExtractionError.unreadableEncoding
        }
        return text
    }
}

struct WebArticleBlockDraft {
    let kind: WebArticleBlockKind
    let text: String
}

/// Keeps semantic source roles throughout post-processing. No PDF-style layout
/// inference, paragraph completion guesses or global read/skip policy.
struct WebArticleBlockCollector {
    let options: WebArticleExtractionOptions
    private(set) var blocks: [WebArticleBlockDraft] = []

    private static let ignoredTags: Set<String> = [
        "script", "style", "noscript", "svg", "nav", "footer",
        "form", "button", "input", "select", "textarea"
    ]

    mutating func collect(_ root: Element) throws {
        try visit(root, depth: 0)
    }

    private mutating func visit(_ element: Element, depth: Int) throws {
        try Task.checkCancellation()
        guard depth <= options.maxDOMDepth else {
            throw WebArticleExtractionError.domTooDeep(maxDepth: options.maxDOMDepth)
        }
        let tag = element.tagName().lowercased()
        if Self.ignoredTags.contains(tag) { return }
        // Preserve author as metadata, rather than repeating the byline as a
        // narration paragraph. Other headers (including h1) stay eligible.
        if tag == "p" && element.hasClass("byline") { return }

        switch tag {
        case "h1", "h2", "h3", "h4", "h5", "h6":
            let level = Int(tag.dropFirst()) ?? 1
            try append(.heading(level: level), element.text())
        case "p":
            try append(.paragraph, element.text())
        case "li":
            // Emit a list item only once. Its nested paragraphs belong to the
            // same item, but nested list items must remain independently typed.
            let own = try Self.nodeText(element, excludingNestedListItems: true, maxDepth: options.maxDOMDepth)
            try append(.listItem, own)
            try collectNestedLists(in: element, depth: depth + 1)
        case "blockquote":
            try append(.quote, element.text())
        case "pre":
            try append(.code, Self.nodeText(element, preserveLines: true, maxDepth: options.maxDOMDepth))
        case "table":
            try append(.table, Self.tableText(element))
        case "figcaption":
            try append(.caption, element.text())
        case "dt", "dd":
            try append(.listItem, element.text())
        default:
            // Walk in DOM order. Text directly inside a generic wrapper must
            // not disappear merely because it lacks a <p>; preserve cautiously.
            var looseText = ""
            for node in element.getChildNodes() {
                try Task.checkCancellation()
                guard let child = node as? Element else {
                    if let text = node as? TextNode { looseText += text.getWholeText() }
                    continue
                }
                let childTag = child.tagName().lowercased()
                if Self.isInline(childTag) {
                    looseText += try Self.nodeText(child, maxDepth: options.maxDOMDepth)
                } else {
                    try append(.preservedContent, looseText)
                    looseText = ""
                    try visit(child, depth: depth + 1)
                }
            }
            try append(.preservedContent, looseText)
        }
    }

    /// Find nested lists even when an HTML wrapper separates them from the
    /// containing list item. Their item text is excluded from the parent.
    private mutating func collectNestedLists(in element: Element, depth: Int) throws {
        try Task.checkCancellation()
        guard depth <= options.maxDOMDepth else {
            throw WebArticleExtractionError.domTooDeep(maxDepth: options.maxDOMDepth)
        }
        for child in element.children() {
            let tag = child.tagName().lowercased()
            if tag == "ol" || tag == "ul" {
                try visit(child, depth: depth)
            } else if tag != "li" {
                try collectNestedLists(in: child, depth: depth + 1)
            }
        }
    }

    private static func isInline(_ tag: String) -> Bool {
        ["a", "span", "em", "strong", "b", "i", "u", "small", "sup", "sub", "mark", "time", "br", "wbr"].contains(tag)
    }

    private mutating func append(_ kind: WebArticleBlockKind, _ raw: String) throws {
        let text: String
        switch kind {
        case .code, .table:
            text = raw.replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        default:
            text = raw.split(whereSeparator: { $0.isWhitespace })
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !text.isEmpty else { return }
        guard blocks.count < options.maxBlocks else {
            throw WebArticleExtractionError.tooManyBlocks(maxBlocks: options.maxBlocks)
        }
        blocks.append(WebArticleBlockDraft(kind: kind, text: text))
    }

    /// Iterative traversal protects against stack overflow from deeply nested
    /// untrusted markup, including a nested list inside one logical item.
    private static func nodeText(
        _ element: Element,
        excludingNestedListItems: Bool = false,
        preserveLines: Bool = false,
        maxDepth: Int
    ) throws -> String {
        struct Frame {
            let node: Node
            let depth: Int
            let isClosing: Bool
        }
        var pieces: [String] = []
        var stack: [Frame] = [Frame(node: element, depth: 0, isClosing: false)]
        while let frame = stack.popLast() {
            try Task.checkCancellation()
            guard frame.depth <= maxDepth else {
                throw WebArticleExtractionError.domTooDeep(maxDepth: maxDepth)
            }
            if let node = frame.node as? TextNode {
                pieces.append(node.getWholeText())
                continue
            }
            guard let child = frame.node as? Element else { continue }
            let tag = child.tagName().lowercased()
            if excludingNestedListItems && frame.depth > 0 && tag == "li" {
                continue
            }
            if tag == "br" {
                pieces.append("\n")
                continue
            }
            let isBlock = tag == "p" || tag == "div"
            if frame.isClosing {
                if isBlock { pieces.append(preserveLines ? "\n" : " ") }
                continue
            }
            if isBlock && !pieces.isEmpty {
                pieces.append(preserveLines ? "\n" : " ")
            }
            if isBlock {
                stack.append(Frame(node: child, depth: frame.depth, isClosing: true))
            }
            for nested in child.getChildNodes().reversed() {
                stack.append(Frame(node: nested, depth: frame.depth + 1, isClosing: false))
            }
        }
        return pieces.joined()
    }

    private static func tableText(_ table: Element) throws -> String {
        var rows: [String] = []
        for row in try table.select("tr") {
            try Task.checkCancellation()
            var cells: [String] = []
            for cell in try row.select("th, td") {
                let value = try cell.text().split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
                if !value.isEmpty { cells.append(value) }
            }
            if !cells.isEmpty { rows.append(cells.joined(separator: "\t")) }
        }
        return rows.joined(separator: "\n")
    }
}
