# TTS Text Format Roadmap

This roadmap focuses on document and text formats that are useful for a normal-user text-to-speech app.

PDF and EPUB are intentionally out of scope because they are handled by dedicated packages.

## Current support

| Format | Extensions | TTS importance | Status | Notes |
| --- | --- | --- | --- | --- |
| Plain text | `.txt`, `.text` | Essential | Supported | Decoding, encoding metadata, whitespace normalization, and `rawText` are available. |
| Markdown | `.md`, `.markdown`, `.mdown`, `.mkd` | High | Supported | Readable-text extraction and raw Markdown are available. |
| HTML | `.html`, `.htm` | High | Supported | Semantic block boundaries are preserved as paragraphs, `<br>` remains a line break, and raw HTML is exposed. |
| Legacy Microsoft Word | `.doc` | Medium | macOS only | Readable body text is imported through Apple's native Microsoft Word document importer. Binary source means `rawText` is `nil`. |
| DOCX | `.docx` | Essential | Supported | Paragraphs, tables, notes, numbering, optional headers/footers, and safety limits are covered. Binary source means `rawText` is `nil`. |
| OpenDocument Text | `.odt` | High | Supported | Headings, paragraphs, nested lists, tables, tabs, line breaks, content sniffing, and ZIP safety limits are covered. Binary source means `rawText` is `nil`. |
| PowerPoint | `.pptx` | High | Supported | Slide relationship order, readable text, tables, per-slide segments, optional speaker notes, content sniffing, and ZIP safety limits are covered. Binary source means `rawText` is `nil`. |
| RTF | `.rtf` | High on Apple platforms | Supported | Parsed text and raw RTF source are available. |
| SubRip | `.srt` | Medium-high | Supported | Cue parsing, timestamps, duplicate rolling-caption cleanup, and raw source are available. |
| WebVTT | `.vtt`, `.webvtt` | Medium-high | Supported | Cue parsing, timestamps, settings handling, and raw source are available. |

## Priority roadmap

### P1 — Rich Text Directory (`.rtfd`)

**Why:** Useful on macOS/iOS and fits the package's Apple-platform focus.

**Implementation direction:**
- treat RTFD as a package/directory containing an RTF document plus attachments
- extract the embedded RTF text using the existing RTF path
- ignore images and unrelated attachments for TTS
- expose raw RTF source when available

### P2 — Saved Web Archive (`.mhtml`, `.mht`)

**Why:** Users sometimes save webpages as MIME HTML archives and expect them to read like HTML.

**Implementation direction:**
- parse MIME structure
- select the primary HTML/text body
- pass HTML through the existing HTML extractor
- ignore binary resources such as images, CSS, fonts, and scripts
- expose the selected HTML source as `rawText`

### P3 — Apple Pages (`.pages`)

**Why:** Relevant to Apple users, but less important than DOCX/ODT.

**Implementation direction:**
- investigate current Pages container structure before committing to support
- prioritize readable text extraction over layout fidelity
- fail clearly for unsupported document generations
- keep the implementation isolated because Pages internals may evolve

## Nice-to-have formats

| Format | Extensions | Priority | Notes |
| --- | --- | --- | --- |
| TextBundle | `.textbundle`, `.textpack` | Low-medium | Useful for Markdown-centric macOS apps; usually straightforward to map to an embedded text/Markdown file. |
| LaTeX | `.tex` | Low-medium | Useful for technical users, but converting commands/math into natural TTS text requires policy decisions. |

## Intentionally low priority / out of scope

| Format | Extensions | Decision | Reason |
| --- | --- | --- | --- |
| CSV / TSV | `.csv`, `.tsv` | Skip for now | Table data rarely sounds natural when read directly. |
| JSON | `.json` | Skip for now | Machine-readable data, poor default TTS experience. |
| XML | `.xml` | Skip for now | Generic XML has no universal reading semantics. |
| Source code | many | Skip for now | Different product problem from normal document TTS. |
| PDF | `.pdf` | Out of scope | Handled by a dedicated package. |
| EPUB | `.epub` | Out of scope | Handled by a dedicated package. |

## Completion target

For a normal-user TTS app, the package should be considered broadly feature-complete once these are solid:

1. current TXT / Markdown / HTML / DOC / DOCX / ODT / PPTX / RTF / SRT / VTT support
2. RTFD
3. MHTML

Pages support is valuable but not required for the core completion target.

## API expectations for every new format

Every new extractor should follow the same package contract:

- return readable TTS-oriented text in `ExtractedTextDocument.text`
- expose decoded source in `rawText` only when a meaningful text source exists
- preserve paragraph boundaries where the source has semantic blocks
- avoid leaking parser-specific errors through the public API
- enforce input and archive safety limits
- include focused unit tests, malformed-input tests, and representative fixtures
- work on both supported Apple platforms unless the format is explicitly platform-limited
