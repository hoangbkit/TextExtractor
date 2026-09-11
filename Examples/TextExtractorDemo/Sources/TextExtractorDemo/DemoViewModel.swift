import Foundation
import TextExtractor

@MainActor
final class DemoViewModel: ObservableObject {
    @Published private(set) var fixtures: [FixtureFile] = []
    @Published private(set) var fixturesDirectory: URL
    @Published private(set) var selectedFixtureID: FixtureFile.ID?
    @Published private(set) var document: ExtractedTextDocument?
    @Published private(set) var isExtracting = false
    @Published private(set) var selectedSourceName: String?
    @Published var errorMessage: String?

    private let extractor = TextExtractor()
    private var extractionTask: Task<Void, Never>?

    init() {
        fixturesDirectory = Self.bundledFixturesDirectory
        reloadFixtures()
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
            guard let enumerator = FileManager.default.enumerator(
                at: fixturesDirectory,
                includingPropertiesForKeys: Array(resourceKeys),
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                throw CocoaError(.fileReadUnknown)
            }

            let supportedExtensions = extractor.supportedFileExtensions
            fixtures = try enumerator
                .compactMap { $0 as? URL }
                .filter { url in
                    let values = try url.resourceValues(forKeys: resourceKeys)
                    return values.isRegularFile == true
                        && values.isHidden != true
                        && supportedExtensions.contains(url.pathExtension.lowercased())
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
                selectFixture(previousSelection)
            } else if let first = fixtures.first {
                selectFixture(first.id)
            } else {
                selectedFixtureID = nil
                selectedSourceName = nil
                document = nil
            }
        } catch {
            fixtures = []
            selectedFixtureID = nil
            selectedSourceName = nil
            document = nil
            errorMessage = "Could not read bundled fixtures: \(Self.describe(error))"
        }
    }

    func selectFixture(_ id: FixtureFile.ID?) {
        selectedFixtureID = id

        guard let id, let fixture = fixtures.first(where: { $0.id == id }) else {
            extractionTask?.cancel()
            selectedSourceName = nil
            document = nil
            return
        }

        extract(url: fixture.url, sourceName: fixture.relativePath)
    }

    func extractImportedFile(url: URL) {
        selectedFixtureID = nil
        extract(url: url, sourceName: url.lastPathComponent)
    }

    private func extract(url: URL, sourceName: String) {
        extractionTask?.cancel()
        selectedSourceName = sourceName
        document = nil
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
                self.errorMessage = nil
            } catch {
                guard !Task.isCancelled else { return }
                self.document = nil
                self.errorMessage = Self.describe(error)
            }

            if !Task.isCancelled {
                self.isExtracting = false
            }
        }
    }

    private static func describe(_ error: Error) -> String {
        if let localized = error as? LocalizedError, let description = localized.errorDescription {
            return description
        }
        return error.localizedDescription
    }

    private static var bundledFixturesDirectory: URL {
        guard let resourceURL = Bundle.main.resourceURL else {
            return URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                .appendingPathComponent("MissingFixtures", isDirectory: true)
        }
        return resourceURL.appendingPathComponent("Fixtures", isDirectory: true)
    }
}
