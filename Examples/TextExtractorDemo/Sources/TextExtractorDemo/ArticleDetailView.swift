import SwiftUI
import TextExtractorWeb

private enum ArticleDetailMode: String, CaseIterable, Identifiable {
    case blocks = "Blocks"
    case text = "Plain Text"
    case metadata = "Metadata"

    var id: Self { self }
}

/// An inspector, not a speech player or re-extractor. It renders the already
/// finalized WebArticleResult without guessing types from flattened text.
struct ArticleDetailView: View {
    let article: WebArticleResult

    @State private var mode: ArticleDetailMode = .blocks

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Article View", selection: $mode) {
                    ForEach(ArticleDetailMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Article output view")

                switch mode {
                case .blocks:
                    typedBlocks
                case .text:
                    Text(article.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                case .metadata:
                    metadataContent
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle(article.title)
        .navigationSubtitle("WEB ARTICLE")
    }

    private var typedBlocks: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            Text("\(article.blocks.count) semantic blocks in reading order")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(article.blocks) { block in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(title(for: block.kind))
                            .font(.subheadline.weight(.semibold))
                        Spacer(minLength: 4)
                        Text(block.id)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }

                    Text(block.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.body)
                        .textSelection(.enabled)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var metadataContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            LabeledContent("Title", value: article.title)
            LabeledContent("Source URL") {
                Text(article.sourceURL.absoluteString)
                    .textSelection(.enabled)
                    .multilineTextAlignment(.trailing)
            }
            LabeledContent("Semantic Blocks", value: "\(article.blocks.count)")

            if article.metadata.isEmpty {
                Text("No additional article metadata was found.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(article.metadata.keys.sorted(), id: \.self) { key in
                    LabeledContent(key) {
                        Text(article.metadata[key] ?? "")
                            .textSelection(.enabled)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func title(for kind: WebArticleBlockKind) -> String {
        switch kind {
        case .paragraph: return "Paragraph"
        case .heading(let level): return "Heading \(level)"
        case .listItem: return "List Item"
        case .quote: return "Quote"
        case .code: return "Code"
        case .table: return "Table"
        case .caption: return "Caption"
        case .preservedContent: return "Preserved Content"
        }
    }
}
