# TextExtractor

Production-oriented Swift Package for extracting readable, narration-friendly text from common document formats.

TextExtractor is designed for macOS and iOS applications that need predictable plain-text output, optional timed segments, stable warnings, and bounded processing of user-controlled files.

## Platforms

- macOS 15+
- iOS 26+
- Swift tools 5.9+

The package manifest intentionally uses string deployment versions so Swift tools 5.9 can express the iOS 26 minimum while the package remains consumable by the macOS 15 CI toolchain.

## Supported formats

| Format | Extensions | Reading behavior |
| --- | --- | --- |
| Plain text | `.txt`, `.text` | Deterministic UTF decoding and whitespace normalization |
| Markdown | `.md`, `.markdown`, `.mdown`, `.mkd` | Raw or speech-oriented readable text |
| SubRip | `.srt` | Timed segments with rolling-caption deduplication |
| WebVTT | `.vtt`, `.webvtt` | Timed segments, cue settings ignored for narration |
| RTF | `.rtf` | Readable attributed-string text on Apple platforms |
| HTML | `.html`, `.htm` | Readable text with script/style/noscript removal |
| DOCX | `.docx` | Reading-order OOXML text, tables, common lists, notes, optional headers/footers |

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
print(document.segments)
print(document.warnings)
```

Extraction from in-memory data is also supported:

```swift
let document = try extractor.extract(
    data: data,
    fileName: "chapter.md"
)
```

## Concurrency

`TextExtractor` and the built-in extractors are `Sendable` and may be reused from concurrent tasks. Extraction is synchronous and can perform file I/O, decoding, XML parsing, ZIP expansion, and normalization, so UI applications should perform it away from the main actor.

```swift
let document = try await Task.detached(priority: .userInitiated) {
    try TextExtractor().extract(from: url)
}.value
```

## Resource limits

`TextExtractionOptions` bounds both source files and DOCX expansion. Current defaults are:

| Option | Default |
| --- | ---: |
| `maxInputBytes` | 50 MiB |
| `maxArchiveEntryBytes` | 64 MiB |
| `maxExpandedArchiveBytes` | 128 MiB |
| `maxArchiveEntryCount` | 2,048 |

Limits are enforced before and during relevant DOCX entry extraction. Policy violations fail through `TextExtractionError` rather than leaking ZIPFoundation errors.

## Warnings and errors

Recoverable degradation is reported through `ExtractedTextDocument.warnings`. `TextExtractionWarning.Code` provides stable machine-readable categories such as malformed subtitle timestamps, skipped optional DOCX parts, unsupported DOCX features, and lossy encoding fallback.

Expected extraction failures are normalized to `TextExtractionError`, including unsupported file types, input-size violations, empty documents, unreadable encodings, invalid documents, and platform limitations.

Applications should branch on warning codes and error cases rather than matching human-readable message strings.

## Format guarantees and limitations

TextExtractor is reading-oriented, not layout-preserving.

- Plain text uses deterministic encoding detection, including UTF-8, BOM-based UTF-16, conservative BOM-less UTF-16 inference, Windows-1252, and Latin-1 fallback after binary rejection.
- Markdown aims for useful narration rather than complete CommonMark rendering.
- SRT/VTT retain usable cue text when timing is malformed and emit a warning when appropriate.
- HTML prefers Apple attributed-string extraction where available and has an intentionally approximate lightweight fallback.
- RTF behavior is based on Apple's attributed-string parser.
- DOCX preserves logical body order, paragraph boundaries, explicit tabs/breaks, tab-separated table cells, common numbering, visible field results, inserted text, and selected optional parts. It does not reproduce Word page layout, styling, floating-object geometry, or every OOXML feature.

Detailed contracts:

- `docs/API_CONTRACTS.md`
- `docs/TEXT_FORMAT_BEHAVIOR.md`
- `docs/DOCX_SEMANTICS.md`
- `docs/PERFORMANCE_AND_RELIABILITY.md`

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

The demo bundles the checked-in `Fixtures` directory, lists every supported fixture file, extracts the selected sample off the main actor, shows the extracted text in a detail view, and provides an **Open File** button for browsing external files.

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

CI verifies the package and unified macOS demo target on:

- Intel macOS 15 (`macos-15-intel`)
- Apple Silicon macOS 15 (`macos-15`)
- Apple Silicon macOS 26 (`macos-26`)

CI also generates the same demo project and builds the iOS target for a generic iOS Simulator destination on the Apple Silicon macOS 26 runner.

See `docs/TESTING.md` for fixture and regression-test guidance.

## Releases

TextExtractor follows semantic versioning. See `docs/VERSIONING.md`, `CHANGELOG.md`, and `docs/RELEASE_CHECKLIST.md` before tagging or synchronizing a revision into Spokio.
