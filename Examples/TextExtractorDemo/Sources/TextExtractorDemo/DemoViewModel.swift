import Foundation
import TextExtractor

@MainActor
final class DemoViewModel: ObservableObject {
    @Published private(set) var fixtures: [FixtureFile] = []
    @Published private(set) var customFiles: [FixtureFile] = []
    @Published private(set) var fixturesDirectory: URL
    @Published private(set) var selectedFixtureID: FixtureFile.ID?
    @Published private(set) var document: ExtractedTextDocument?
    @Published private(set) var isExtracting = false
    @Published private(set) var selectedSourceName: String?
    @Published var errorMessage: String?
    @Published var importErrorMessage: String?

    private let extractor = TextExtractor()
    private var extractionTask: Task<Void, Never>?

    init() {
        fixturesDirectory = Self.bundledFixturesDirectory
        reloadFixtures()
        reloadCustomFiles()
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

            if let previousSelection,
               fixtures.contains(where: { $0.id == previousSelection }) {
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

    func reloadCustomFiles() {
        do {
            let directory = try Self.customSamplesDirectory()
            let urls = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
            let supportedExtensions = extractor.supportedFileExtensions

            customFiles = try urls
                .filter { url in
                    let values = try url.resourceValues(forKeys: [.isRegularFileKey])
                    return values.isRegularFile == true
                        && supportedExtensions.contains(url.pathExtension.lowercased())
                }
                .map { url in
                    FixtureFile(
                        url: url,
                        relativePath: "Custom/\(url.lastPathComponent)"
                    )
                }
                .sorted { $0.fileName.localizedStandardCompare($1.fileName) == .orderedAscending }
        } catch {
            customFiles = []
            importErrorMessage = "Could not load custom files: \(Self.describe(error))"
        }
    }

    func selectFixture(_ id: FixtureFile.ID?) {
        selectedFixtureID = id

        guard let id else {
            extractionTask?.cancel()
            selectedSourceName = nil
            document = nil
            return
        }

        if let customFile = customFiles.first(where: { $0.id == id }) {
            extract(url: customFile.url, sourceName: customFile.fileName)
            return
        }

        guard let fixture = fixtures.first(where: { $0.id == id }) else {
            extractionTask?.cancel()
            selectedSourceName = nil
            document = nil
            return
        }

        extract(url: fixture.url, sourceName: fixture.relativePath)
    }

    func importCustomFile(url: URL) {
        do {
            let extensionName = url.pathExtension.lowercased()
            guard extractor.supportedFileExtensions.contains(extensionName) else {
                throw DemoImportError.unsupportedFileExtension(extensionName)
            }

            let hasSecurityScopedAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasSecurityScopedAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let directory = try Self.customSamplesDirectory()
            let destination = Self.uniqueDestination(for: url, in: directory)
            try FileManager.default.copyItem(at: url, to: destination)
            importErrorMessage = nil
            reloadCustomFiles()
        } catch {
            importErrorMessage = Self.describe(error)
        }
    }

    func removeCustomFile(_ file: FixtureFile) {
        removeCustomFiles([file])
    }

    func removeCustomFiles(at offsets: IndexSet) {
        let files = offsets.compactMap { index in
            customFiles.indices.contains(index) ? customFiles[index] : nil
        }
        removeCustomFiles(files)
    }

    private func removeCustomFiles(_ files: [FixtureFile]) {
        guard !files.isEmpty else { return }

        do {
            for file in files {
                try FileManager.default.removeItem(at: file.url)
                if selectedFixtureID == file.id {
                    extractionTask?.cancel()
                    selectedFixtureID = nil
                    selectedSourceName = nil
                    document = nil
                    isExtracting = false
                }
            }
            importErrorMessage = nil
            reloadCustomFiles()
        } catch {
            importErrorMessage = "Could not remove custom file: \(Self.describe(error))"
        }
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

    private static func customSamplesDirectory() throws -> URL {
        guard let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw CocoaError(.fileNoSuchFile)
        }

        let directory = applicationSupport
            .appendingPathComponent("TextExtractorDemo", isDirectory: true)
            .appendingPathComponent("CustomSamples", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }

    private static func uniqueDestination(for sourceURL: URL, in directory: URL) -> URL {
        let fileManager = FileManager.default
        let originalName = sourceURL.lastPathComponent
        var destination = directory.appendingPathComponent(originalName)
        guard fileManager.fileExists(atPath: destination.path) else {
            return destination
        }

        let fileExtension = sourceURL.pathExtension
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        var suffix = 2

        while fileManager.fileExists(atPath: destination.path) {
            let candidateName = fileExtension.isEmpty
                ? "\(baseName) \(suffix)"
                : "\(baseName) \(suffix).\(fileExtension)"
            destination = directory.appendingPathComponent(candidateName)
            suffix += 1
        }
        return destination
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

private enum DemoImportError: LocalizedError {
    case unsupportedFileExtension(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFileExtension(let fileExtension):
            let displayExtension = fileExtension.isEmpty ? "this file type" : ".\(fileExtension)"
            return "TextExtractor does not support \(displayExtension)."
        }
    }
}
