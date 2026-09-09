# TextExtractorIOSDemo

An iOS 26+ SwiftUI demo for the `TextExtractor` package.

The Xcode project is generated with XcodeGen and is intentionally not committed.

## Generate

```bash
cd Examples/TextExtractorIOSDemo
xcodegen generate
open TextExtractorIOSDemo.xcodeproj
```

The project links the local package at `../..`.

## What it demonstrates

- In-memory Markdown extraction.
- Document import through the system file importer.
- Security-scoped file access.
- Extraction away from the main actor.
- Display of normalized text and structured warnings.

CI generates this project and builds it for a generic iOS Simulator destination on the `macos-26` Apple Silicon runner.
