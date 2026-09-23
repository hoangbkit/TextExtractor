# Changelog

All notable caller-visible changes to TextExtractor are recorded here.

The project follows Semantic Versioning; see `docs/VERSIONING.md`.

## Unreleased

No changes yet.

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
