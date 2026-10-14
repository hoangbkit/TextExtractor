import Foundation

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

enum DemoSidebarSelection: Hashable {
    case file(FixtureFile.ID)
    case article(DemoArticleSample.ID)
}
