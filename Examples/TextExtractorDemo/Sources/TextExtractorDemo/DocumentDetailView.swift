import SwiftUI
import TextExtractor

struct DocumentDetailView: View {
    let document: ExtractedTextDocument
    @Binding var selectedTab: DemoTab

    var body: some View {
        VStack(spacing: 0) {
            header

            Picker("View", selection: $selectedTab) {
                Text("Text").tag(DemoTab.text)
                Text("Segments (\(document.segments.count))").tag(DemoTab.segments)
                Text("Metadata").tag(DemoTab.metadata)
            }
            .pickerStyle(.segmented)
            .padding([.horizontal, .bottom])

            Divider()

            switch selectedTab {
            case .text:
                ExtractedTextView(text: document.text)
            case .segments:
                SegmentListView(segments: document.segments)
            case .metadata:
                MetadataView(document: document)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(document.title)
                        .font(.title2.bold())
                        .lineLimit(1)
                    Text(document.format.rawValue.uppercased())
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            HStack(spacing: 10) {
                StatPill(title: "Characters", value: document.demoCharacterCount.formatted())
                StatPill(title: "Words", value: document.demoWordCount.formatted())
                StatPill(title: "Lines", value: document.demoLineCount.formatted())
                StatPill(title: "Segments", value: document.segments.count.formatted())
            }
        }
        .padding()
    }
}

private struct StatPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.monospacedDigit())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct ExtractedTextView: View {
    let text: String

    var body: some View {
        ScrollView {
            Text(text.isEmpty ? "No text extracted." : text)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .padding()
        }
    }
}

private struct SegmentListView: View {
    let segments: [ExtractedTextSegment]

    var body: some View {
        if segments.isEmpty {
            EmptyStateView(
                title: "No segments",
                systemImage: "text.bubble",
                message: "This format produced one plain text document instead of timestamped segments."
            )
        } else {
            List(segments) { segment in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(segment.id)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)

                        if let start = segment.startTime, let end = segment.endTime {
                            Text("\(start.demoTimestamp) → \(end.demoTimestamp)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(segment.text)
                        .textSelection(.enabled)
                }
                .padding(.vertical, 4)
            }
        }
    }
}

private struct MetadataView: View {
    let document: ExtractedTextDocument

    var body: some View {
        List {
            Section("Source") {
                LabeledContent("Title", value: document.title)
                LabeledContent("Format", value: document.format.rawValue)
                if let sourceURL = document.sourceURL {
                    LabeledContent("URL", value: sourceURL.path)
                }
            }

            if !document.metadata.isEmpty {
                Section("Metadata") {
                    ForEach(document.metadata.keys.sorted(), id: \.self) { key in
                        LabeledContent(key, value: document.metadata[key] ?? "")
                    }
                }
            }

            if !document.warnings.isEmpty {
                Section("Warnings") {
                    ForEach(Array(document.warnings.enumerated()), id: \.offset) { _, warning in
                        Text(warning.description)
                    }
                }
            }
        }
    }
}
