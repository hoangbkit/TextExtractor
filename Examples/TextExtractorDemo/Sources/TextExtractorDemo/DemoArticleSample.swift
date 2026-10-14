import Foundation
import TextExtractorWeb

/// Offline inputs used only by the demo. Their URLs represent the original
/// source pages for metadata and relative-link resolution, not network fetches.
struct DemoArticleSample: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let fileName: String
    let sourceURL: URL

    static let bundled: [Self] = [
        .init(
            id: "garden",
            title: "Garden Article",
            fileName: "garden-article.html",
            sourceURL: URL(string: "https://example.org/stories/garden")!
        ),
        .init(
            id: "field-journal",
            title: "Structured Article",
            fileName: "structured-article.html",
            sourceURL: URL(string: "https://example.org/stories/field-journal")!
        ),
        .init(
            id: "navigation-only",
            title: "Non-article (Expected Failure)",
            fileName: "navigation-only.html",
            sourceURL: URL(string: "https://example.org/navigation")!
        )
    ]

    var bundledURL: URL? {
        Bundle.main.resourceURL?
            .appendingPathComponent("ArticleSamples", isDirectory: true)
            .appendingPathComponent(fileName, isDirectory: false)
    }
}

/// Stored canonical article output. A saved URL never needs to be fetched
/// again just to open its typed block inspector.
struct DemoSavedArticle: Identifiable, Codable, Sendable {
    let id: String
    let article: WebArticleResult

    var title: String { article.title }
    var sourceURL: URL { article.sourceURL }
}

enum DemoSidebarSelection: Hashable {
    case file(FixtureFile.ID)
    case article(DemoArticleSample.ID)
}
