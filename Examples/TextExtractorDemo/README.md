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
- Bundles three standalone offline HTML examples from `ArticleSamples/` for the optional `TextExtractorWeb` product.
- Adds a separate **Web Articles** section in the sidebar; selecting one opens a typed article inspector rather than the generic HTML-to-text view.
- The article inspector can switch between **Blocks** (kind, stable occurrence ID, text), **Plain Text** (derived from typed blocks), and **Metadata** (title, source URL, known article fields) using the toolbar **Article Options** button and a dedicated Form sheet with **Done**. The scrollable content area contains **no sticky options header**.
- Includes a navigation-only sample that intentionally demonstrates how an unreadable/non-article failure is displayed.
- The web article feature has **no network fetch**; the example URLs are provenance inputs, not requests.
- Lists every bundled file whose extension is supported by `TextExtractor`.
- Extracts the selected sample away from the main actor and shows the extracted text in the detail view. Parsed/Raw display choice is in a **Document Options** toolbar sheet, not a segmented control occupying the toolbar/content area.
- Provides an **Open File** button using the system file importer for external files.
- Supports the package's plain text, Markdown, SRT, WebVTT, RTF, HTML, DOCX, ODT, and PPTX extensions on macOS and iOS, plus legacy DOC on macOS.

The `Fixtures` and `ArticleSamples` folders are copied into the app bundle as separate folder resources by XcodeGen, so neither demo flow requires a source checkout at runtime. The existing document imports continue to use core `TextExtractor` without changing its output models.

The demo project keeps a single XcodeGen spec with two schemes, and `TextExtractorWeb` is linked independently into both apps. Generated `.xcodeproj` files remain ignored in git; the planned release workflow will publish a generated project ZIP for mycli.

## Command line

Build the macOS demo:

```bash
make build
```

Build the iOS demo for the Simulator:

```bash
make ios-build
```

CI workflows are manual-only. Full CI can regenerate and build the macOS
target on Intel macOS 15, Apple Silicon macOS 15 and Apple Silicon macOS 26;
the iOS target is built for an iOS 26 Simulator on macOS 26. These checks
have not been run against the new article demo yet.

## Demo Release for mycli

The [Demo Release](../../.github/workflows/demo-release.yml) workflow is
**manual-only** (`workflow_dispatch`). After this workflow is available on the
repository default branch, open **Actions → Demo Release → Run workflow** and
choose the branch/commit, platform (`macOS`, `iOS`, or `both`) and one build
configuration (`Release` or `Debug`). The defaults are `both` and `Release`.

The workflow generates the Xcode project with XcodeGen, builds the selected
unsigned device-ready archive(s) with Xcode 26.3, and publishes one GitHub
**prerelease** using the tag `mycli-build-<run-id>-<attempt>`. No automatic
push or PR builds are triggered, and signing is left to the local deployment
machine.

With `both` selected, exactly three ZIP assets are expected:

```text
TextExtractorDemo-iOS-unsigned-<tag>.xcarchive.zip
TextExtractorDemo-macOS-universal-unsigned-<tag>.xcarchive.zip
TextExtractorDemo-xcodeproj-<tag>.zip
```

The iOS asset contains one unsigned **iPhone-device** `.xcarchive`, not a
Simulator app. The macOS archive contains a universal `arm64 + x86_64` app.
The Xcode project ZIP has one top-level `TextExtractorDemo.xcodeproj/` folder
with `project.pbxproj` and its shared schemes. This last asset is consumed
by mycli for build settings **without regenerating XcodeGen locally**.
The generated project is never committed; `project.yml` remains the source
of truth. A local source checkout, Xcode, and signing credentials are still
required.

From `Examples/TextExtractorDemo` in a local checkout, deploy a generated
prerelease with:

```bash
mycli deploy mac --release
mycli deploy ios --release
```

Use `--tag mycli-build-<run-id>-<attempt>` to select a specific build.
Publishing one configuration per release avoids ambiguous app assets in mycli.
A macOS-only or iOS-only dispatch includes the project ZIP plus only the
selected platform's archive.

**Status:** This workflow has been implemented in PR #6 but has not been
dispatched or build-tested; its first real build and deployment are separate
from implementation.
