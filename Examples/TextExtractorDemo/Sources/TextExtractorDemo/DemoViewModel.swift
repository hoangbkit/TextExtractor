import Foundation
import TextExtractor

@MainActor
final class DemoViewModel: ObservableObject {
    @Published private(set) var fixtures: [FixtureFile] = []
    @Published private(set) var fixturesDirectory: URL
    @Published private(set) var selectedFixtureID: FixtureFile.ID?
    @Published private(set) var document: ExtractedTextDocument?
    @Published private(set) var isExtracting = false
    @Published var errorMessage: String?
    @Published var selectedTab: DemoTab = .text

    private let extractor = TextExtractor()
    private var extractionTask: Task<Void, Never>?

    init() {
        fixturesDirectory = Self.defaultFixturesDirectory
        reloadFixtures()
    }

    var supportedExtensionSummary: String {
        extractor.supportedFileExtensions
            .sorted()
            .map { ".\($0)" }
            .joined(separator: ", ")
    }

    var fixtureSections: [FixtureSection] {
        Dictionary(grouping: fixtures, by: \.folderName)
            .map { FixtureSection(name: $0.key, files: $0.value.sorted { $0.fileName < $1.fileName }) }
            .sorted { $0.name < $1.name }
    }

    func reloadFixtures() {
        let previousSelection = selectedFixtureID

        do {
            let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey, .isHiddenKey]
            let urls = try FileManager.default.contentsOfDirectory(
                at: fixturesDirectory,
                includingPropertiesForKeys: Array(resourceKeys),
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            )

            let fileURLs = urls.flatMap { url -> [URL] in
                if url.hasDirectoryPath {
                    guard let enumerator = FileManager.default.enumerator(
                        at: url,
                        includingPropertiesForKeys: Array(resourceKeys),
                        options: [.skipsHiddenFiles, .skipsPackageDescendants]
                    ) else {
                        return []
                    }
                    return enumerator.compactMap { $0 as? URL }
                }
                return [url]
            }

            fixtures = try fileURLs
                .filter { url in
                    let values = try url.resourceValues(forKeys: resourceKeys)
                    return values.isRegularFile == true && values.isHidden != true
                }
                .map { url in
                    FixtureFile(
                        url: url,
                        relativePath: url.path.replacingOccurrences(
                            of: fixturesDirectory.path + "/",
                            with: ""
                        )
                    )
                }
                .sorted { $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending }

            errorMessage = nil

            if let previousSelection, fixtures.contains(where: { $0.id == previousSelection }) {
                selectedFixtureID = previousSelection
            } else if let first = fixtures.first {
                selectFixture(first.id)
            } else {
                selectedFixtureID = nil
                document = nil
            }
        } catch {
            fixtures = []
            selectedFixtureID = nil
            document = nil
            errorMessage = "Could not read \(fixturesDirectory.path): \(Self.describe(error))"
        }
    }

    func selectFixture(_ id: FixtureFile.ID?) {
        guard selectedFixtureID != id else { return }
        selectedFixtureID = id

        guard let id, let fixture = fixtures.first(where: { $0.id == id }) else {
            extractionTask?.cancel()
            document = nil
            return
        }

        extract(url: fixture.url)
    }

    func extractImportedFile(url: URL) {
        selectedFixtureID = nil
        extract(url: url)
    }

    func extract(url: URL) {
        extractionTask?.cancel()
        errorMessage = nil
        isExtracting = true

        extractionTask = Task {
            do {
                let document = try await Task.detached(priority: .userInitiated) {
                    var options = TextExtractionOptions()
                    options.includeDOCXHeadersAndFooters = true
                    return try TextExtractor().extract(from: url, options: options)
                }.value

                guard !Task.isCancelled else { return }
                self.document = document
                self.selectedTab = .text
            } catch {
                guard !Task.isCancelled else { return }
                self.document = nil
                self.errorMessage = Self.describe(error)
            }

            self.isExtracting = false
        }
    }

    func reset() {
        extractionTask?.cancel()
        selectedFixtureID = nil
        document = nil
        errorMessage = nil
        selectedTab = .text
        isExtracting = false
    }

    private static func describe(_ error: Error) -> String {
        if let localized = error as? LocalizedError, let description = localized.errorDescription {
            return description
        }
        return error.localizedDescription
    }

    private static var defaultFixturesDirectory: URL {
        var repositoryRoot = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 {
            repositoryRoot.deleteLastPathComponent()
        }
        return repositoryRoot.appendingPathComponent("Fixtures", isDirectory: true)
    }
}

enum DemoTab: Hashable {
    case text
    case segments
    case metadata
}
