# Changelog

All notable caller-visible changes to TextExtractor are recorded here.

The project follows Semantic Versioning; see `docs/VERSIONING.md`.

## Unreleased

### Added

- Optional `TextExtractorWeb` SwiftPM library product with its own public typed article model: `WebArticleBlockKind`, `WebArticleBlock`, `WebArticleResult`, and `WebArticleExtractor`.
- Offline main-article extraction from caller-supplied HTML and source URL using SwiftReadability and SwiftSoup, including semantic ordered blocks, deterministic occurrence-based block IDs, and derived plain-text output.
- Web-article metadata (`author`, `siteName`, `language`, `publishedTime` when available), typed extraction/model errors, cancellation checks, and configurable input/DOM/block limits.
- Separate web-article inspector in both TextExtractorDemo apps with bundled offline examples, typed block details, derived plain text, metadata, and error display.
- Manual-only Demo Release workflow for unsigned universal macOS archives, unsigned iOS device archives, and a generated Xcode project ZIP consumable by mycli.
- Dedicated web-article fixtures, golden-output tests, DOM-structure tests, and standalone API documentation.

### Compatibility and limitations

- Existing `Sources/TextExtractor/**`, existing public `ExtractedTextDocument`, default extraction routing, and core format semantics are unchanged. `TextExtractorWeb` has an independent result contract; it is not automatically registered as a generic HTML extractor.
- `WebArticleExtractor` **does not download pages or execute JavaScript**. It cannot guarantee extraction from paywalled, authenticated, JavaScript-only, or non-article pages.
- SwiftReadability is pinned to 0.3.3 and requires Swift 6.2. Because SwiftPM may resolve dependency manifests package-wide, compatibility with older toolchains is **not yet established**, even for apps using only the original `TextExtractor` product.
- As directed during development, the new web product, demo UI, and release workflow **have not been built or validated**; manual CI and release/deployment gates remain open. Do not treat this entry as a release approval.

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
