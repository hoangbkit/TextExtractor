# TextExtractorDemo

A macOS 15+ SwiftUI demo for the `TextExtractor` package.

The Xcode project is generated with XcodeGen and is intentionally not committed.

## Generate and open

```bash
cd Examples/TextExtractorDemo
xcodegen generate
open TextExtractorDemo.xcodeproj
```

Then select the `TextExtractorDemo` scheme and run.

The generated project links the local package at `../..`, so keep the demo inside the `TextExtractor` repository.

## What it demos

- Import `.txt`, `.md`, `.markdown`, `.srt`, `.vtt`, `.rtf`, `.html`, `.htm`, and `.docx` files.
- Preview normalized TTS-ready text.
- Preview subtitle segments with timestamps.
- Inspect metadata, warnings, character count, word count, line count, and segment count.
- Browse every file under the repository's `Fixtures` directory.
- Refresh the sidebar after adding or removing fixture files without rebuilding the app.

## Notes

The demo resolves `Fixtures` from the source checkout path embedded at compile time, so the repository should remain at the same path while the built app is running.

CI regenerates this project with XcodeGen and builds it on Intel macOS 15, Apple Silicon macOS 15, and Apple Silicon macOS 26 runners.
