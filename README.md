# TextExtractor

Production-oriented Swift Package for extracting readable, narration-friendly text from common document formats.

TextExtractor is designed for macOS and iOS applications that need predictable plain-text output, optional timed segments, stable warnings, and bounded processing of user-controlled files.

> **Project status:** This repository is public, but it is not actively maintained as a traditional open-source project.

## Platforms

- macOS 15+
- iOS 26+
- Swift tools 5.9+ for the existing core package manifest and core sources; **the optional `TextExtractorWeb` product currently depends on SwiftReadability 0.3.3, which requires Swift 6.2**. Since SwiftPM resolves dependency manifests package-wide, older toolchain compatibility must be checked before release.

The package manifest intentionally uses string deployment versions so Swift tools 5.9 can express the iOS 26 minimum while the package remains consumable by the macOS 15 CI toolchain.

## Supported formats

| Format | Extensions | Reading behavior |
| --- | --- | --- |
| Plain text | `.txt`, `.text` | Deterministic UTF decoding and whitespace normalization |
| Markdown | `.md`, `.markdown`, `.mdown`, `.mkd` | Raw or speech-oriented readable text |
| SubRip | `.srt` | Timed segments with rolling-caption deduplication |
| WebVTT | `.vtt`, `.webvtt` | Timed segments, cue settings ignored for narration |
| RTF | `.rtf` | Readable attributed-string text on Apple platforms |
| HTML | `.html`, `.htm` | Readable text with semantic paragraph boundaries and script/style/noscript removal |
| Legacy Microsoft Word | `.doc` | macOS only — readable body text through Apple's native Word document importer |
| DOCX | `.docx` | Reading-order OOXML text, tables, common lists, notes, optional headers/footers |
| OpenDocument Text | `.odt` | Reading-order ODF text with headings, lists, tables, tabs, and line breaks |
| PowerPoint | `.pptx` | Slides in presentation order with readable text, tables, and optional speaker notes |

**Web articles** are available through the separate, opt-in `TextExtractorWeb` product, which selects the primary readable article from supplied HTML and preserves ordered typed semantic blocks. This does not change generic `.html` / `.htm` extraction in core.

PDF and EPUB are intentionally outside this package because they require different extraction and layout strategies.

## Installation

In Xcode, add the package dependency:

```text
https://github.com/hoangbkit/TextExtractor.git
```

For production applications, depend on a tagged semantic version rather than a moving branch or commit unless you intentionally pin revisions.

## Basic usage

```swift
import TextExtractor

let extractor = TextExtractor()
let document = try extractor.extract(from: url)

print(document.title)
print(document.format)
print(document.text)
print(document.rawText)
print(document.segments)
print(document.warnings)
```

`document.text` is the normalized, reading-oriented output. `document.rawText` contains decoded source text before format parsing and whitespace normalization when a meaningful textual source exists. Text-based formats such as TXT, Markdown, HTML, SRT, VTT, and RTF expose it; binary document/container formats such as DOC, DOCX, ODT, and PPTX leave it `nil`.

Extraction from in-memory data is also supported:

```swift
let document = try extractor.extract(
    data: data,
    fileName: "chapter.md"
)
```

## Optional TextExtractorWeb article extraction

`TextExtractorWeb` adds a **standalone, optional module** for extracting the primary
readable article from an already downloaded HTML snapshot. It uses
[SwiftReadability](https://github.com/wolfyy970/swift-readability) and
[SwiftSoup](https://github.com/scinfu/SwiftSoup). It does not make network
requests, execute JavaScript, or alter core `TextExtractor` types.

In your SwiftPM target, depend on the `TextExtractorWeb` **product** from this
package (rather than adding a new URL). Example:

```swift
import Foundation
import TextExtractorWeb

let sourceURL = URL(string: "https://example.com/blog/field-notes")!
let article = try WebArticleExtractor().extract(
    html: htmlData,
    sourceURL: sourceURL
)

print(article.title)
print(article.metadata["author"] ?? "Unknown author")
for block in article.blocks {
    print(block.id, block.kind, block.text)
}
print(article.text)
```

`WebArticleResult.blocks` is the authoritative, ordered semantic representation:
`paragraph`, `heading(level:)`, `listItem`, `quote`, `code`, `table`,
`caption`, and `preservedContent`. `article.text` is **derived from those
blocks** with blank lines between blocks, not an independently reconstructed
string. Block IDs are deterministic for the same source and segmentation,
but **not** a persistent identity across content or parser-version changes.
Semantic blocks are not TTS synthesis chunks.

The result includes the article title, source URL, and available metadata using
documented stable keys. No global read/skip policy is applied. Extraction
throws for invalid URLs, oversized inputs, unsupported encodings, unreadable
articles, or limit violations. Supply the **final webpage URL** if redirects
occurred before providing HTML; the extractor never follows redirects itself.

Defaults limit input HTML to 5 MiB, parsed DOM elements to 50,000, DOM depth to
128 and output to 10,000 blocks. These are **not** a browser-style time or
memory sandbox: parse off the main actor and impose an external timeout/resource
budget on untrusted inputs. JavaScript-only, paywalled, authenticated, and
non-article pages are not guaranteed to produce readable output. Source HTML
is not retained in the result.

Full API/normalization details: [Web article contract](docs/WEB_ARTICLE_CONTRACT.md).
The new module is unreleased and its build/regression validation has been
deferred, so do not treat this API example as a verified production release.

## Concurrency

`TextExtractor` and the built-in extractors are `Sendable` and may be reused from concurrent tasks. Extraction is synchronous and can perform file I/O, decoding, XML parsing, ZIP expansion, and normalization, so UI applications should perform it away from the main actor.

```swift
let document = try await Task.detached(priority: .userInitiated) {
    try TextExtractor().extract(from: url)
}.value
```

## Resource limits

`TextExtractionOptions` bounds source files and archive-backed document expansion. Current defaults are:

| Option | Default |
| --- | ---: |
| `maxInputBytes` | 50 MiB |
| `maxArchiveEntryBytes` | 64 MiB |
| `maxExpandedArchiveBytes` | 128 MiB |
| `maxArchiveEntryCount` | 2,048 |

Limits are enforced before and during relevant DOCX, ODT, and PPTX entry extraction. Policy violations fail through `TextExtractionError` rather than leaking ZIPFoundation errors.

## Warnings and errors

Recoverable degradation is reported through `ExtractedTextDocument.warnings`. `TextExtractionWarning.Code` provides stable machine-readable categories such as malformed subtitle timestamps, skipped optional DOCX parts, unsupported DOCX features, and lossy encoding fallback.

Expected extraction failures are normalized to `TextExtractionError`, including unsupported file types, input-size violations, empty documents, unreadable encodings, invalid documents, and platform limitations.

Applications should branch on warning codes and error cases rather than matching human-readable message strings.

## Format guarantees and limitations

TextExtractor is reading-oriented, not layout-preserving.

- Plain text uses deterministic encoding detection, including UTF-8, BOM-based UTF-16, conservative BOM-less UTF-16 inference, Windows-1252, and Latin-1 fallback after binary rejection.
- Markdown aims for useful narration rather than complete CommonMark rendering.
- SRT/VTT retain usable cue text when timing is malformed and emit a warning when appropriate.
- HTML preserves semantic block boundaries for paragraphs/headings, keeps `<br>` as a line break, prefers Apple attributed-string extraction where available, and has an intentionally approximate lightweight fallback.
- RTF behavior is based on Apple's attributed-string parser.
- Legacy DOC is supported on macOS only and uses Apple's native Microsoft Word attributed-string importer for readable body text. It does not attempt to reproduce page layout, floating objects, or Word-specific editing semantics.
- DOCX preserves logical body order, paragraph boundaries, explicit tabs/breaks, tab-separated table cells, common numbering, visible field results, inserted text, and selected optional parts. It does not reproduce Word page layout, styling, floating-object geometry, or every OOXML feature.
- ODT reads `content.xml` in document order, preserves headings and paragraphs, keeps list items distinct, renders table rows with tab-separated cells, and preserves explicit tabs/line breaks. It does not reproduce page layout or styling.
- PPTX follows the presentation relationship order, extracts readable DrawingML text and table rows, exposes one segment per non-empty slide, and includes speaker notes by default. Set `includePPTXSpeakerNotes` to `false` to omit notes. Charts, SmartArt interpretation, animations, images, and visual layout are intentionally not reconstructed.

Detailed contracts and planning:

- `docs/API_CONTRACTS.md`
- `docs/TEXT_FORMAT_BEHAVIOR.md`
- `docs/DOCX_SEMANTICS.md`
- `docs/PERFORMANCE_AND_RELIABILITY.md`
- `docs/TTS_FORMAT_ROADMAP.md`

## Custom extractors

Passing a custom extractor array replaces the built-in extractor set. Ordering matters: the first extractor matching an extension wins, and extension matches take precedence over content sniffing.

```swift
struct MyExtractor: TextFormatExtractor {
    let format: TextExtractionFormat = .plainText
    let supportedFileExtensions: Set<String> = ["custom"]

    func canExtract(data: Data, fileName: String?) -> Bool {
        true
    }

    func extract(
        data: Data,
        fileName: String?,
        sourceURL: URL?,
        options: TextExtractionOptions
    ) throws -> ExtractedTextDocument {
        ExtractedTextDocument(
            title: fileName ?? "Document",
            sourceURL: sourceURL,
            format: format,
            text: String(decoding: data, as: UTF8.self)
        )
    }
}

let extractor = TextExtractor(extractors: [MyExtractor()])
```

## Demo app

The repository has one XcodeGen demo project with shared SwiftUI sources and two application targets:

- `TextExtractorDemo-macOS` — macOS 15+, tested on Intel and Apple Silicon
- `TextExtractorDemo-iOS` — iOS 26+

Both targets use bundle identifier `com.hoangbkit.text.extractor.demo`. Generated `.xcodeproj` directories are intentionally ignored and must not be committed.

```bash
cd Examples/TextExtractorDemo
xcodegen generate
open TextExtractorDemo.xcodeproj
```

The demo's **Library** sidebar lists persisted user-added documents and URL articles, followed by bundled file and article samples. The toolbar **+** menu provides **Browse Files** and **Add Article URL**. The demo (not `TextExtractorWeb`) fetches supplied HTTPS pages once and stores the extracted typed result locally for offline reopening. Article details offer **Blocks**, **Plain Text**, and **Metadata** modes in a toolbar options sheet; document details retain **Parsed** and **Raw** modes. Existing generic HTML extraction and external file imports are preserved. See [the demo README](Examples/TextExtractorDemo/README.md).

## Development

Normal package verification:

```bash
swift test --parallel
swift build -c release
```

Generate/build the macOS demo:

```bash
make build
```

Generate/build the iOS demo for the Simulator:

```bash
make ios-build
```

Install XcodeGen first when working locally:

```bash
brew install xcodegen
```

Timing benchmarks are opt-in so normal CI does not depend on runner speed:

```bash
TEXTEXTRACTOR_RUN_BENCHMARKS=1 swift test --filter Phase5BenchmarkTests
```

All three workflows are **manual-only** (`workflow_dispatch`):

- **Fast CI** runs package tests on macOS 26.
- **Full CI** runs package tests and a release build, generates the XcodeGen demo project, builds the macOS demo on Intel macOS 15, Apple Silicon macOS 15, and Apple Silicon macOS 26, and builds the iOS demo for a generic iOS Simulator on macOS 26.
- **Demo Release** creates unsigned iOS device and/or universal macOS demo archives plus a generated `.xcodeproj` ZIP in a `mycli-build-*` GitHub prerelease. It supports one Debug or Release configuration per run and never commits the generated project.

Choose the branch/ref in **GitHub Actions → selected workflow → Run workflow**.
See `docs/TESTING.md` for regression-test guidance and
`Examples/TextExtractorDemo/README.md` for release/deploy instructions.
The new workflows have not been manually dispatched or verified on this PR.

## Releases

TextExtractor follows semantic versioning. See `docs/VERSIONING.md`, `CHANGELOG.md`, and `docs/RELEASE_CHECKLIST.md` before tagging a release. For the standalone web feature, also consult `docs/WEB_ARTICLE_RELEASE_CHECKLIST.md`. Generated `mycli-build-*` demo prereleases are **not** Swift package version tags.
