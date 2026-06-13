# TextExtractorDemo

A small macOS SwiftUI Xcode project that demonstrates the `TextExtractor` package.

## Open in Xcode

Open:

```text
Examples/TextExtractorDemo/TextExtractorDemo.xcodeproj
```

Then select the `TextExtractorDemo` scheme and run.

The project links the package at `../..`, so keep the demo inside the `TextExtractor` repository/folder.

## What it demos

- Import `.txt`, `.md`, `.markdown`, `.srt`, `.vtt`, `.rtf`, `.html`, `.htm`, and `.docx` files.
- Preview normalized TTS-ready text.
- Preview subtitle segments with timestamps.
- Inspect metadata, warnings, character count, word count, line count, and segment count.
- Browse every file under the repository's `Fixtures` directory.
- Refresh the sidebar after adding or removing fixture files without rebuilding the app.

## Notes

The demo is intentionally not sandboxed. It resolves `Fixtures` from the source checkout path embedded at compile time, so the repository should remain at the same path while the built app is running.

DOCX extraction uses the root package dependency on `ZIPFoundation`, so Xcode may fetch that package the first time you open/build the project.
