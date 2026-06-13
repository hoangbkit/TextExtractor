import SwiftUI
import TextExtractor

struct ContentView: View {
    @StateObject private var viewModel = DemoViewModel()
    @State private var isImporterPresented = false

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 340)
        } detail: {
            detail
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: SupportedContentTypes.readableTextImports,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    viewModel.extractImportedFile(url: url)
                }
            case .failure(let error):
                viewModel.errorMessage = error.localizedDescription
            }
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            List(selection: fixtureSelection) {
                ForEach(viewModel.fixtureSections) { section in
                    Section(section.name.uppercased()) {
                        ForEach(section.files) { fixture in
                            Label {
                                Text(fixture.fileName)
                            } icon: {
                                Image(systemName: iconName(for: fixture.fileExtension))
                                    .foregroundStyle(.secondary)
                            }
                            .tag(fixture.id)
                        }
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()

            HStack {
                Button {
                    viewModel.reloadFixtures()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }

                Spacer()

                Button {
                    isImporterPresented = true
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
                .disabled(viewModel.isExtracting)
            }
            .buttonStyle(.borderless)
            .padding(12)
        }
        .navigationTitle("Fixtures")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if viewModel.isExtracting {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
    }

    private var fixtureSelection: Binding<FixtureFile.ID?> {
        Binding(
            get: { viewModel.selectedFixtureID },
            set: { viewModel.selectFixture($0) }
        )
    }

    @ViewBuilder
    private var detail: some View {
        if let errorMessage = viewModel.errorMessage {
            EmptyStateView(
                title: "Import failed",
                systemImage: "exclamationmark.triangle",
                message: errorMessage
            )
        } else if let document = viewModel.document {
            DocumentDetailView(document: document, selectedTab: $viewModel.selectedTab)
        } else {
            EmptyStateView(
                title: "Select a fixture",
                systemImage: "doc.text.magnifyingglass",
                message: "Choose a file from \(viewModel.fixturesDirectory.path) to see its extracted text."
            )
        }
    }

    private func iconName(for fileExtension: String) -> String {
        switch fileExtension {
        case "srt", "vtt": "captions.bubble"
        case "html", "htm": "globe"
        case "md", "markdown": "text.document"
        case "docx": "doc.richtext"
        default: "doc.text"
        }
    }
}
