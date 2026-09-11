# TextExtractorDemo

A single SwiftUI demo project for `TextExtractor`, generated with XcodeGen and shared by:

- `TextExtractorDemo-macOS` — macOS 15+, Intel and Apple Silicon
- `TextExtractorDemo-iOS` — iOS 26+

Both targets use the bundle identifier `com.hoangbkit.text.extractor.demo` and development team `J458WW3452`.

Generated `.xcodeproj` directories are intentionally ignored and must not be committed.

## Generate and open

```bash
cd Examples/TextExtractorDemo
xcodegen generate
open TextExtractorDemo.xcodeproj
```

Choose either demo scheme in Xcode.

## What it demos

- Bundles the repository `Fixtures` directory into both apps.
- Lists every bundled file whose extension is supported by `TextExtractor`.
- Extracts the selected sample away from the main actor and shows the extracted text in the detail view.
- Provides an **Open File** button using the system file importer for external files.
- Supports the package's plain text, Markdown, SRT, WebVTT, RTF, HTML, and DOCX extensions.

The fixture folder is copied into the app bundle by XcodeGen as a folder resource, so the built demo does not depend on the source checkout path at runtime.

## Command line

Build the macOS demo:

```bash
make build
```

Build the iOS demo for the Simulator:

```bash
make ios-build
```

CI regenerates the same project and builds the macOS target on Intel macOS 15, Apple Silicon macOS 15, and Apple Silicon macOS 26 runners. The iOS target is built for an iOS 26 Simulator destination on the macOS 26 runner.
