# Text Format Behavior

This document describes the text-oriented extraction behavior established in Phase 3 of the quality and safety roadmap. The goal is predictable, speech-friendly output rather than complete reproduction of source formatting.

## Plain text and encoding

Text decoding is deterministic and reports the selected encoding in `ExtractedTextDocument.metadata["encoding"]`.

Detection order:

1. UTF-8 BOM (`utf-8-bom`)
2. UTF-16 little-endian BOM (`utf-16le-bom`)
3. UTF-16 big-endian BOM (`utf-16be-bom`)
4. strongly inferred UTF-16 little-endian (`utf-16le-inferred`)
5. strongly inferred UTF-16 big-endian (`utf-16be-inferred`)
6. UTF-8 (`utf-8`)
7. Windows-1252 (`windows-1252`)
8. ISO-8859-1 (`iso-8859-1`)

The UTF-16 inference step uses a strong alternating-NUL heuristic before UTF-8 decoding so ordinary BOM-less UTF-16 text is not accepted as NUL-filled UTF-8. Binary-looking payloads are rejected before permissive legacy decoding. Windows-1252 and ISO-8859-1 are treated as legacy fallbacks and emit the stable `lossyEncodingFallback` warning code.

## Markdown

Readable Markdown extraction intentionally remains lightweight and speech-oriented rather than implementing the full CommonMark grammar.

Handled narration cases include:

- ATX and Setext headings
- unordered, ordered, nested quote, and task-list markers
- inline links and reference links while dropping destinations
- HTTP autolinks omitted and `mailto:` autolinks reduced to the email address
- variable-length backtick and tilde fenced code blocks
- indented code blocks when code dropping is enabled
- inline code, emphasis, strong emphasis, and strikethrough cleanup
- reference definitions removed from narration
- common Markdown tables flattened into readable cell text
- common escaped Markdown punctuation restored without treating escaped emphasis markers as formatting

`MarkdownExtractionMode.raw` remains available when callers want to preserve Markdown syntax.

## SRT and WebVTT

Subtitle extraction preserves deterministic segment IDs and original source cue IDs in metadata when present.

When duplicate-line removal is enabled, consecutive rolling captions use conservative word-overlap removal. For example, `We are`, `We are going`, `are going home` becomes narration equivalent to `We are`, `going`, `home`. Original casing is preserved.

Malformed timestamps do not discard otherwise usable cue text. The segment keeps the readable text with unavailable timing fields and the document emits `malformedSubtitleTimestamp`.

WebVTT header, NOTE, STYLE, REGION, cue settings, and inline subtitle markup are handled as narration metadata/markup rather than spoken text.

## HTML

On Apple platforms the primary HTML extractor may use `NSAttributedString` HTML import. The lightweight `BasicHTMLTextExtractor` remains the fallback path, so exact whitespace can differ between the two paths.

The fallback is intentionally approximate but handles common narration concerns:

- comments removed
- script, style, and noscript content removed
- common block elements converted to text boundaries
- table cells separated before normalization
- quoted `>` characters inside tag attributes do not prematurely terminate tag stripping
- HTML entities decoded after tag removal

It is not intended to be a full browser-grade HTML parser.

## RTF

RTF extraction uses the Apple attributed-string importer on supported platforms. Formatting is removed while readable text, paragraphs, and encoded text characters are retained. Malformed RTF is normalized to `TextExtractionError.invalidDocument` instead of exposing lower-level Foundation errors.

## Fixtures and regression coverage

The package CI exercises the checked-in short, medium, and long fixture corpus for every supported text-like format, in addition to targeted unit tests for the behaviors above.

## DOCX scope

This Phase 3 behavior document does not redefine DOCX reading semantics. DOCX semantic fidelity, tables, numbering, tracked changes, notes, headers, and related OOXML behavior are handled separately in Phase 4.
