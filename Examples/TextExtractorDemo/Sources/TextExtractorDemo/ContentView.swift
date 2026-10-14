import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = DemoViewModel()
    @StateObject private var articleViewModel = DemoArticleViewModel()
    @State private var isImporterPresented = false
    @State private var showsAddURL = false
    @State private var articleURLInput = ""

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
                    articleViewModel.selectArticle(nil)
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
        .alert("Could Not Add Article", isPresented: articleErrorPresented) {
            Button("OK", role: .cancel) {
                articleViewModel.addErrorMessage = nil
            }
        } message: {
            Text(articleViewModel.addErrorMessage ?? "Unknown error")
        }
        .sheet(isPresented: $showsAddURL) {
            addArticleURLSheet
        }
    }

    private var sidebar: some View {
        List(selection: sidebarSelection) {
            if !articleViewModel.savedArticles.isEmpty || !viewModel.customFiles.isEmpty {
                Section("ADDED") {
                    ForEach(articleViewModel.savedArticles) { article in
                        savedArticleLink(article)
                            .contextMenu {
                                Button(role: .destructive) {
                                    articleViewModel.removeSavedArticle(article)
                                } label: {
                                    Label("Remove Article", systemImage: "trash")
                                }
                            }
                    }
                    .onDelete { offsets in
                        let entries = offsets.compactMap { index in
                            articleViewModel.savedArticles.indices.contains(index)
                                ? articleViewModel.savedArticles[index] : nil
                        }
                        for article in entries {
                            articleViewModel.removeSavedArticle(article)
                        }
                    }

                    ForEach(viewModel.customFiles) { file in
                        sampleLink(file)
                            .contextMenu {
                                Button(role: .destructive) {
                                    viewModel.removeCustomFile(file)
                                } label: {
                                    Label("Remove Document", systemImage: "trash")
                                }
                            }
                    }
                    .onDelete(perform: viewModel.removeCustomFiles)
                }
            }

            if articleViewModel.isAddingArticle {
                Section {
                    ProgressView("Adding article…")
                }
            }

            Section("ARTICLE SAMPLES") {
                ForEach(articleViewModel.samples) { sample in
                    articleLink(sample)
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
                Menu {
                    Button {
                        isImporterPresented = true
                    } label: {
                        Label("Browse Files", systemImage: "folder")
                    }
                    Button {
                        articleURLInput = ""
                        showsAddURL = true
                    } label: {
                        Label("Add Article URL", systemImage: "link")
                    }
                    .disabled(articleViewModel.isAddingArticle)
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .accessibilityLabel("Add")
            }
        }
    }

    private func sampleLink(_ file: FixtureFile) -> some View {
        NavigationLink(value: DemoSidebarSelection.file(file.id)) {
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

    private func savedArticleLink(_ saved: DemoSavedArticle) -> some View {
        NavigationLink(value: DemoSidebarSelection.article(saved.id)) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(saved.title)
                    Text(saved.sourceURL.host ?? saved.sourceURL.absoluteString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "globe")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func articleLink(_ sample: DemoArticleSample) -> some View {
        NavigationLink(value: DemoSidebarSelection.article(sample.id)) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(sample.title)
                    Text(sample.fileName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "text.book.closed")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var sidebarSelection: Binding<DemoSidebarSelection?> {
        Binding(
            get: {
                if let id = articleViewModel.selectedArticleID {
                    return .article(id)
                }
                return viewModel.selectedFixtureID.map(DemoSidebarSelection.file)
            },
            set: { selection in
                switch selection {
                case .some(.article(let id)):
                    viewModel.selectFixture(nil)
                    articleViewModel.selectArticle(id)
                case .some(.file(let id)):
                    articleViewModel.selectArticle(nil)
                    viewModel.selectFixture(id)
                case nil:
                    articleViewModel.selectArticle(nil)
                    viewModel.selectFixture(nil)
                }
            }
        )
    }

    private var addArticleURLSheet: some View {
        NavigationStack {
            Form {
                Section("Article URL") {
                    TextField("https://example.com/article", text: $articleURLInput)
#if os(iOS)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
#endif
                        .autocorrectionDisabled()
                }
                Section {
                    Text("The demo downloads HTML once, extracts typed article blocks, and saves the result for offline reading. HTTPS pages only.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add Article URL")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showsAddURL = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let address = articleURLInput
                        showsAddURL = false
                        viewModel.selectFixture(nil)
                        articleViewModel.selectArticle(nil)
                        articleViewModel.addArticleURL(address)
                    }
                    .disabled(articleURLInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
#if os(macOS)
        .frame(minWidth: 440, idealWidth: 520, minHeight: 240)
#endif
    }

    private var articleErrorPresented: Binding<Bool> {
        Binding(
            get: { articleViewModel.addErrorMessage != nil },
            set: { presented in
                if !presented { articleViewModel.addErrorMessage = nil }
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

    @ViewBuilder
    private var detail: some View {
        if articleViewModel.isAddingArticle {
            ProgressView("Adding Article…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if articleViewModel.selectedArticleID != nil {
            if articleViewModel.isExtracting {
                ProgressView("Extracting Article…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = articleViewModel.errorMessage {
                ContentUnavailableView(
                    "Article Extraction Failed",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else if let article = articleViewModel.result {
                ArticleDetailView(article: article)
                    .id(articleViewModel.selectedArticleID)
            } else {
                ContentUnavailableView(
                    "No Article",
                    systemImage: "doc.text",
                    description: Text("Choose an article from the list.")
                )
            }
        } else if viewModel.isExtracting {
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
                description: Text("Choose an item or use Add to import a file or article URL.")
            )
        }
    }

    private func iconName(for fileExtension: String) -> String {
        switch fileExtension {
        case "srt", "vtt", "webvtt": "captions.bubble"
        case "html", "htm": "globe"
        case "md", "markdown", "mdown", "mkd": "text.document"
        case "doc", "docx", "odt": "doc.richtext"
        case "pptx": "rectangle.on.rectangle"
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
    @State private var showsOptions = false

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
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showsOptions = true
                } label: {
                    Label("Document Options", systemImage: "slider.horizontal.3")
                }
                .accessibilityLabel("Document Options")
            }
        }
        .sheet(isPresented: $showsOptions) {
            optionsSheet
        }
    }

    private var optionsSheet: some View {
        NavigationStack {
            Form {
                Section("Content View") {
                    Picker("Show", selection: $mode) {
                        ForEach(DetailContentMode.allCases) { choice in
                            Text(choice.rawValue).tag(choice)
                        }
                    }
                    .pickerStyle(.inline)
                }
                Section {
                    Text("Parsed shows the readable extracted document. Raw shows the original decoded source text when available.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Document Options")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showsOptions = false }
                }
            }
        }
#if os(macOS)
        .frame(minWidth: 380, idealWidth: 440, minHeight: 310)
#endif
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
