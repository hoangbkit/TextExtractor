# Changelog

All notable caller-visible changes to TextExtractor are recorded here.

The project follows Semantic Versioning; see `docs/VERSIONING.md`.

## Unreleased

### Added

- CI verification for package tests, release builds, and the macOS demo app.
- Automated coverage for the existing short/medium/long fixture corpus.
- DOCX archive expansion limits for individual entries, cumulative selected content, and archive entry count.
- Machine-readable `TextExtractionWarning.Code` values.
- Deterministic unique subtitle segment IDs while preserving source cue IDs in metadata.
- Encoding provenance and legacy-encoding warnings.
- Reading-oriented DOCX table, numbering, tracked-change, field-result, note, header/footer, content-control, and text-box handling.
- Deterministic mutation, large-input, repeat-extraction, concurrency, and opt-in benchmark coverage.
- Public API, format semantics, reliability, versioning, and release documentation.

### Changed

- DOCX content sniffing now verifies that a ZIP contains `word/document.xml` rather than treating every ZIP as DOCX.
- Data-based DOCX extraction reads from an in-memory archive rather than materializing temporary package directories.
- Text decoding rejects likely binary payloads before permissive legacy fallbacks.
- UTF-16 BOM handling is strict; conservative BOM-less UTF-16 inference is supported.
- Markdown extraction handles more common speech-oriented structures and preserves escaped emphasis markers correctly.
- Rolling subtitle captions emit only newly added words when overlap can be identified conservatively.
- Malformed subtitle timestamps can retain readable text while emitting a warning.
- HTML fallback parsing has stronger block, table, comment, and script/style/noscript handling.
- DOCX explicit tabs and breaks are preserved; table cells are tab-separated and rows remain in reading order.
- Common Word numbering formats and start overrides are resolved where practical.
- Optional DOCX notes and headers/footers use deterministic ordering and filtering.

### Fixed

- Potential DOCX archive-expansion/resource abuse paths.
- Temporary-directory leakage during data-based DOCX extraction.
- Arbitrary binary data being narrated through Latin-1 fallback.
- Low-level DOCX/RTF failures escaping expected package-domain error/warning boundaries.
- Repeated subtitle source IDs violating `Identifiable` uniqueness expectations.
- Nested DOCX deleted-content and field-instruction parser state.

### Compatibility notes

- Existing primary public entry points remain source-compatible.
- Archive safety options are additive and defaulted.
- Warning codes are additive; the legacy message-only warning initializer remains available.
- No PDF or EPUB support is included.

When the first release tag is created, move these entries under that version and date before starting a new `Unreleased` section.
