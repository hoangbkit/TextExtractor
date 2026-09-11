import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = DemoViewModel()
    @State private var isImporterPresented = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @State private var preferredCompactColumn: NavigationSplitViewColumn = .sidebar

    var body: some View {
        NavigationSplitView(
            columnVisibility: $columnVisibility,
            preferredCompactColumn: $preferredCompactColumn
        ) {
            sidebar
        } detail: {
            detail
        }
#if os(macOS)
        .navigationSplitViewStyle(.balanced)
#endif
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: SupportedContentTypes.readableTextImports,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    viewModel.importCustomFile(url: url)
                }
            case .failure(let error):
                viewModel.importErrorMessage = error.localizedDescription
            }
        }
        .alert("Could Not Add File", isPresented: importErrorPresented) {
            Button("OK", role: .cancel) {
                viewModel.importErrorMessage = nil
            }
        } message: {
            Text(viewModel.importErrorMessage ?? "Unknown error")
        }
    }

    private var sidebar: some View {
        List(selection: fixtureSelection) {
            if !viewModel.customFiles.isEmpty {
                Section("CUSTOM") {
                    ForEach(viewModel.customFiles) { file in
                        sampleLink(file)
                            .contextMenu {
                                Button(role: .destructive) {
                                    viewModel.removeCustomFile(file)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                    }
                    .onDelete(perform: viewModel.removeCustomFiles)
                }
            }

            ForEach(viewModel.fixtureSections) { section in
                Section(section.name.uppercased()) {
                    ForEach(section.files) { fixture in
                        sampleLink(fixture)
                    }
                }
            }
        }
#if os(macOS)
        .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 380)
#endif
        .navigationTitle("Samples")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isImporterPresented = true
                } label: {
                    Label("Open File", systemImage: "folder")
                }
                .disabled(viewModel.isExtracting)
            }
        }
    }

    private func sampleLink(_ file: FixtureFile) -> some View {
        NavigationLink(value: file.id) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(file.fileName)
                    Text(file.relativePath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: iconName(for: file.fileExtension))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var fixtureSelection: Binding<FixtureFile.ID?> {
        Binding(
            get: { viewModel.selectedFixtureID },
            set: { id in
                viewModel.selectFixture(id)
                if id != nil {
                    showDetail()
                }
            }
        )
    }

    private var importErrorPresented: Binding<Bool> {
        Binding(
            get: { viewModel.importErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.importErrorMessage = nil
                }
            }
        )
    }

    private func showDetail() {
        preferredCompactColumn = .detail
        columnVisibility = .detailOnly
    }

    @ViewBuilder
    private var detail: some View {
        if viewModel.isExtracting {
            ProgressView("Extracting…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage = viewModel.errorMessage {
            ContentUnavailableView(
                "Extraction Failed",
                systemImage: "exclamationmark.triangle",
                description: Text(errorMessage)
            )
        } else if let document = viewModel.document {
            ExtractedTextDetailView(
                sourceName: viewModel.selectedSourceName ?? document.title,
                format: document.format.rawValue,
                text: document.text
            )
        } else {
            ContentUnavailableView(
                "Select a File",
                systemImage: "doc.text.magnifyingglass",
                description: Text("Choose a bundled sample or open an external file.")
            )
        }
    }

    private func iconName(for fileExtension: String) -> String {
        switch fileExtension {
        case "srt", "vtt", "webvtt": "captions.bubble"
        case "html", "htm": "globe"
        case "md", "markdown", "mdown", "mkd": "text.document"
        case "docx": "doc.richtext"
        default: "doc.text"
        }
    }
}

private struct ExtractedTextDetailView: View {
    let sourceName: String
    let format: String
    let text: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(sourceName)
                        .font(.title2.bold())
                        .textSelection(.enabled)
                    Text(format.uppercased())
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }

                Divider()

                Text(text.isEmpty ? "No text extracted." : text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .padding()
        }
        .navigationTitle("Extracted Text")
    }
}
