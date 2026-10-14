import Foundation
import TextExtractorWeb

/// Owns sample and user-added URL articles. The demo persists canonical typed
/// results locally so added URLs can reopen without another network request.
/// No downloader or persistence code enters the TextExtractorWeb package.
@MainActor
final class DemoArticleViewModel: ObservableObject {
    let samples = DemoArticleSample.bundled

    @Published private(set) var savedArticles: [DemoSavedArticle] = []
    @Published private(set) var selectedArticleID: String?
    @Published private(set) var result: WebArticleResult?
    @Published private(set) var isExtracting = false
    @Published private(set) var isAddingArticle = false
    @Published private(set) var errorMessage: String?
    @Published var addErrorMessage: String?

    private var extractionTask: Task<Void, Never>?
    private var addTask: Task<Void, Never>?

    init() {
        reloadSavedArticles()
    }

    func selectArticle(_ id: String?) {
        extractionTask?.cancel()
        extractionTask = nil
        selectedArticleID = id
        result = nil
        errorMessage = nil
        isExtracting = false

        guard let id else { return }

        if let saved = savedArticles.first(where: { $0.id == id }) {
            result = saved.article
            return
        }
        guard let sample = samples.first(where: { $0.id == id }) else { return }
        isExtracting = true

        extractionTask = Task { [sample] in
            let work = Task.detached(priority: .userInitiated) {
                guard let url = sample.bundledURL else {
                    throw DemoArticleError.sampleMissing(sample.fileName)
                }
                let html = try Data(contentsOf: url)
                try Task.checkCancellation()
                return try WebArticleExtractor().extract(
                    html: html,
                    sourceURL: sample.sourceURL
                )
            }

            do {
                let parsed = try await withTaskCancellationHandler {
                    try await work.value
                } onCancel: {
                    work.cancel()
                }
                guard !Task.isCancelled else { return }
                result = parsed
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
            }
            guard !Task.isCancelled else { return }
            isExtracting = false
            extractionTask = nil
        }
    }

    func addArticleURL(_ address: String) {
        guard !isAddingArticle else { return }
        addErrorMessage = nil
        isAddingArticle = true

        addTask = Task {
            do {
                // Network I/O and parsing both remain off the main actor.
                let article = try await Task.detached(priority: .userInitiated) {
                    try await DemoArticleDownloader.downloadAndExtract(address)
                }.value
                try Task.checkCancellation()

                if let existing = savedArticles.first(where: {
                    $0.sourceURL == article.sourceURL
                }) {
                    selectArticle(existing.id)
                } else {
                    let saved = DemoSavedArticle(id: UUID().uuidString, article: article)
                    try Self.persist(saved)
                    savedArticles.insert(saved, at: 0)
                    selectArticle(saved.id)
                }
            } catch {
                guard !Task.isCancelled else { return }
                addErrorMessage = Self.describe(error)
            }

            guard !Task.isCancelled else { return }
            isAddingArticle = false
            addTask = nil
        }
    }

    func removeSavedArticle(_ saved: DemoSavedArticle) {
        do {
            guard UUID(uuidString: saved.id) != nil else {
                throw DemoArticleError.invalidSavedArticle
            }
            let location = try Self.articlesDirectory()
                .appendingPathComponent(saved.id + ".json")
            try FileManager.default.removeItem(at: location)
            savedArticles.removeAll { $0.id == saved.id }
            if selectedArticleID == saved.id { selectArticle(nil) }
            addErrorMessage = nil
        } catch {
            addErrorMessage = "Could not remove article: " + Self.describe(error)
        }
    }

    private func reloadSavedArticles() {
        do {
            let directory = try Self.articlesDirectory()
            let files = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ).filter { $0.pathExtension == "json" }
            var loaded: [DemoSavedArticle] = []
            for file in files {
                guard UUID(uuidString: file.deletingPathExtension().lastPathComponent) != nil else {
                    continue
                }
                // A corrupt record is ignored without losing other saved pages.
                guard let data = try? Data(contentsOf: file),
                      let record = try? JSONDecoder().decode(DemoSavedArticle.self, from: data),
                      file.lastPathComponent == record.id + ".json" else { continue }
                loaded.append(record)
            }
            savedArticles = loaded.sorted {
                $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
        } catch {
            savedArticles = []
            addErrorMessage = "Could not load saved articles: " + Self.describe(error)
        }
    }

    private static func persist(_ saved: DemoSavedArticle) throws {
        let directory = try articlesDirectory()
        let file = directory.appendingPathComponent(saved.id + ".json")
        let data = try JSONEncoder().encode(saved)
        try data.write(to: file, options: .atomic)
    }

    private static func articlesDirectory() throws -> URL {
        guard let base = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first else { throw DemoArticleError.storageUnavailable }

        let directory = base
            .appendingPathComponent("TextExtractorDemo", isDirectory: true)
            .appendingPathComponent("SavedArticles", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true
        )
        return directory
    }

    private static func describe(_ error: Error) -> String {
        if let error = error as? LocalizedError,
           let description = error.errorDescription {
            return description
        }
        return error.localizedDescription
    }
}

private enum DemoArticleError: LocalizedError {
    case sampleMissing(String)
    case storageUnavailable
    case invalidSavedArticle

    var errorDescription: String? {
        switch self {
        case .sampleMissing(let name):
            return "The bundled article sample \(name) could not be found."
        case .storageUnavailable:
            return "Application Support storage is unavailable."
        case .invalidSavedArticle:
            return "The saved article identifier is invalid."
        }
    }
}
