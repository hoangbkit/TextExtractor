# Changelog

All notable caller-visible changes to TextExtractor are recorded here.

The project follows Semantic Versioning; see `docs/VERSIONING.md`.

## 1.2.0 — 2026-10-15

### Added

- Optional `TextExtractorWeb` SwiftPM library product with its own public typed article model: `WebArticleBlockKind`, `WebArticleBlock`, `WebArticleResult`, and `WebArticleExtractor`.
- Offline main-article extraction from caller-supplied HTML and source URL using SwiftReadability and SwiftSoup, including semantic ordered blocks, deterministic occurrence-based block IDs, and derived plain-text output.
- Web-article metadata (`author`, `siteName`, `language`, `publishedTime` when available), typed extraction/model errors, cancellation checks, and configurable input/DOM/block limits.
- Separate web-article inspector in both TextExtractorDemo apps with bundled offline examples, typed block details, derived plain text, metadata, and error display.
- Demo Library **+** menu with Browse Files and Add Article URL, including demo-only bounded HTTPS downloading, persisted typed JSON article results for offline reopening, and removal of saved articles.
- Manual-only Demo Release workflow for unsigned universal macOS archives, unsigned iOS device archives, and a generated Xcode project ZIP consumable by mycli.
- Dedicated web-article fixtures, golden-output tests, DOM-structure tests, and standalone API documentation.

### Fixed

- Prefer a retained article H1 when available. When Readability drops the H1, remove a site-name suffix from the page title **only when it matches publisher metadata**, and use the normalized title consistently for the result and restored heading. Preserve meaningful title punctuation and avoid blind separator splitting.

### Compatibility and limitations

- Existing `Sources/TextExtractor/**`, existing public `ExtractedTextDocument`, default extraction routing, and core format semantics are unchanged. `TextExtractorWeb` has an independent result contract; it is not automatically registered as a generic HTML extractor.
- `WebArticleExtractor` **does not download pages or execute JavaScript**. It cannot guarantee extraction from paywalled, authenticated, JavaScript-only, or non-article pages.
- **Minimum build toolchain is now Swift 6.2+ for the whole package**, including core-only consumers: SwiftReadability 0.3.3 declares `swift-tools-version: 6.2`, and SwiftPM resolves its manifest package-wide. Swift 6.1.2 was confirmed to fail dependency resolution. The root manifest still declares 5.9; that does **not** make older compilers compatible. OS deployment minimums remain macOS 15.0 and iOS 26.0.
- Package tests passed [Fast CI #38686086127](https://github.com/hoangbkit/TextExtractor/actions/runs/38686086127), the Intel/Apple Silicon macOS 15 and macOS 26 build/test matrix plus iOS 26 Simulator build passed [Full CI #38690127546](https://github.com/hoangbkit/TextExtractor/actions/runs/38690127546), and unsigned demo archives plus the Xcode project ZIP were published by [Demo Release #38681709018](https://github.com/hoangbkit/TextExtractor/actions/runs/38681709018). These runs predate the documentation-only release commit; rerun release gates as needed against the final tag commit.
- Physical-device execution, locally signed mycli deployment, and interactive demo inspection remain separate, unverified release checks.

## 1.1.0 — 2026-09-23

### Added

- OpenDocument Text (`.odt`) support with headings, paragraphs, nested lists, tables, tabs, line breaks, content sniffing, and archive safety limits.
- Legacy Microsoft Word (`.doc`) support on macOS using Apple's native Word document importer for readable body text.
- PowerPoint (`.pptx`) support with presentation-order slide extraction, slide text, tables, per-slide segments, optional speaker notes, content sniffing, and archive safety limits.
- `includePPTXSpeakerNotes` extraction option, enabled by default.

### Changed

- DOCX, ODT, and PPTX now share the same bounded ZIP entry-count and expanded-size safety implementation.
- Demo app importing now supports ODT and PPTX on macOS/iOS, plus legacy DOC on macOS.

### Compatibility notes

- Existing primary extraction APIs remain source-compatible.
- New extraction options are additive and provide defaults.
- Binary document formats including DOC, DOCX, ODT, and PPTX return `rawText == nil`.
- PDF and EPUB remain intentionally outside TextExtractor and are handled by dedicated parsers.
