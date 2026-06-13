# TextExtractor

Production-oriented Swift Package for extracting readable text from common document formats before sending text to TTS engines.

Built for macOS/iOS apps such as Spokio where every import is normalized into clean plain text plus optional segments.

## Supported MVP formats

- `.txt`
- `.md`, `.markdown`
- `.srt`
- `.vtt`
- `.rtf`
- `.html`, `.htm`
- `.docx`

DOCX support extracts readable body text from WordprocessingML. It does not try to reproduce Word layout.

## Install

Add this package to Xcode:

```text
/path/to/TextExtractor
```

or use it as a remote Swift Package after pushing it to your repo.

## Usage

```swift
import TextExtractor

let extractor = TextExtractor()
let document = try extractor.extract(from: url)

print(document.title)
print(document.text)
print(document.segments)
```

For UI apps, run extraction off the main actor:

```swift
let document = try await Task.detached(priority: .userInitiated) {
    try TextExtractor().extract(from: url)
}.value
```

## TTS pipeline

```text
File URL → TextExtractor → ExtractedTextDocument.text → chunker → TTS provider
```

## Notes

- RTF/HTML use `NSAttributedString` on Apple platforms when available, with a lightweight fallback for HTML.
- DOCX uses ZIPFoundation to read the `.docx` package.
- PDF/EPUB are intentionally not included in this MVP package because they need heavier extraction and cleanup strategies.

## Demo app

A small macOS SwiftUI Xcode project demo app is included in:

```text
Examples/TextExtractorDemo/TextExtractorDemo.xcodeproj
```

The demo links this local package at `../..`. Open the `.xcodeproj`, select the `TextExtractorDemo` scheme, and run.

The demo lets you import files, run extraction off the main actor, and inspect normalized text, subtitle segments, metadata, and warnings. It also includes built-in TXT, Markdown, SRT, VTT, and HTML samples.
