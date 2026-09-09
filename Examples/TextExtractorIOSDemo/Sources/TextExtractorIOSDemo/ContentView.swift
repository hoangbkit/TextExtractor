import SwiftUI
import TextExtractor
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var document: ExtractedTextDocument?
    @State private var errorMessage: String?
    @State private var isImporterPresented = false
    @State private var isWorking = false

    var body: some View {
        NavigationStack {
            Group {
                if let document {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Label(document.format.rawValue.uppercased(), systemImage: "doc.text")
                                Spacer()
                                Text("\(document.text.count) chars")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.caption)

                            if !document.warnings.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Warnings")
                                        .font(.headline)
                                    ForEach(Array(document.warnings.enumerated()), id: \.offset) { _, warning in
                                        Text("• \(warning.code.rawValue): \(warning.message)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }

                            Text(document.text)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding()
                    }
                } else if let errorMessage {
                    ContentUnavailableView(
                        "Extraction failed",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                } else {
                    ContentUnavailableView {
                        Label("TextExtractor", systemImage: "doc.text.magnifyingglass")
                    } description: {
                        Text("Run the built-in Markdown sample or import a document to exercise the package on iOS 26+.")
                    } actions: {
                        Button("Run Markdown Sample") {
                            runSample()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("TextExtractor Demo")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isImporterPresented = true
                    } label: {
                        Label("Import", systemImage: "square.and.arrow.down")
                    }
                    .disabled(isWorking)
                }

                ToolbarItem(placement: .topBarLeading) {
                    if isWorking {
                        ProgressView()
                    } else if document != nil || errorMessage != nil {
                        Button("Sample") {
                            runSample()
                        }
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    importDocument(at: url)
                }
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }

    private func runSample() {
        let markdown = """
        # TextExtractor on iOS

        This **Markdown** document is extracted in memory.

        - TXT, Markdown, subtitles, RTF, HTML, and DOCX are supported.
        - Parsing stays synchronous internally, so the demo runs it off the main actor.
        """
        extract(data: Data(markdown.utf8), fileName: "sample.md")
    }

    private func importDocument(at url: URL) {
        isWorking = true
        errorMessage = nil

        Task {
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let data = try Data(contentsOf: url)
                let fileName = url.lastPathComponent
                let result = try await Task.detached(priority: .userInitiated) {
                    try TextExtractor().extract(data: data, fileName: fileName)
                }.value
                document = result
            } catch {
                document = nil
                errorMessage = error.localizedDescription
            }

            isWorking = false
        }
    }

    private func extract(data: Data, fileName: String) {
        isWorking = true
        errorMessage = nil

        Task {
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    try TextExtractor().extract(data: data, fileName: fileName)
                }.value
                document = result
            } catch {
                document = nil
                errorMessage = error.localizedDescription
            }

            isWorking = false
        }
    }
}
