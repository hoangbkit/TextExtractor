import Foundation
import TextExtractorWeb

/// Separate from the existing document-import model: article demo selection
/// never changes the core TextExtractor parsing or fixture-management path.
@MainActor
final class DemoArticleViewModel: ObservableObject {
    let samples = DemoArticleSample.bundled

    @Published private(set) var selectedSampleID: DemoArticleSample.ID?
    @Published private(set) var result: WebArticleResult?
    @Published private(set) var isExtracting = false
    @Published private(set) var errorMessage: String?

    private var extractionTask: Task<Void, Never>?

    func selectSample(_ id: DemoArticleSample.ID?) {
        extractionTask?.cancel()
        extractionTask = nil
        selectedSampleID = id
        result = nil
        errorMessage = nil
        isExtracting = false

        guard let id, let sample = samples.first(where: { $0.id == id }) else {
            return
        }
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
}

private enum DemoArticleError: LocalizedError {
    case sampleMissing(String)

    var errorDescription: String? {
        switch self {
        case .sampleMissing(let fileName):
            return "The bundled article sample \(fileName) could not be found."
        }
    }
}
