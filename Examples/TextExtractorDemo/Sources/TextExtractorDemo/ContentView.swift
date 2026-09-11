import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = DemoViewModel()
    @State private var isImporterPresented = false

    var body: some View {
        NavigationSplitView {
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
            set: { viewModel.selectFixture($0) }
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
                parsedText: document.text,
                rawText: document.rawText
            )
            .id(viewModel.selectedFixtureID)
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

private enum DetailContentMode: String, CaseIterable, Identifiable {
    case parsed = "Parsed"
    case raw = "Raw"

    var id: Self { self }
}

private struct ExtractedTextDetailView: View {
    let sourceName: String
    let format: String
    let parsedText: String
    let rawText: String?

    @State private var mode: DetailContentMode = .parsed

    var body: some View {
        ScrollView {
            Text(displayedText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .padding()
        }
        .navigationTitle(sourceName)
        .navigationSubtitle(format.uppercased())
        .toolbar {
            ToolbarItem {
                Picker("View", selection: $mode) {
                    ForEach(DetailContentMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
        }
    }

    private var displayedText: String {
        switch mode {
        case .parsed:
            return parsedText.isEmpty ? "No text extracted." : parsedText
        case .raw:
            return rawText ?? "Raw source text is unavailable for this binary format."
        }
    }
}
