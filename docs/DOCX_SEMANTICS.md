# DOCX Reading Semantics

This document defines the reading-oriented DOCX behavior established in Phase 4 of the TextExtractor quality and safety roadmap.

TextExtractor extracts readable document content. It does not attempt to reproduce Microsoft Word layout, pagination, typography, floating-object placement, or visual styling.

## Body order

The main `word/document.xml` body is read in logical XML order.

- ordinary paragraphs remain separate paragraphs
- explicit Word line breaks remain line breaks when paragraph preservation is enabled
- explicit Word tabs remain tab characters
- readable text inside hyperlinks and content controls is retained
- readable text nested in drawing/text-box content is retained when exposed as ordinary WordprocessingML text

## Tracked changes and fields

Tracked deletion state is depth-aware.

- deleted content is excluded, including nested deleted regions
- inserted content remains visible
- field instruction text is omitted
- visible field result text is retained when it appears as normal text content

This behavior is intended for narration and reading, not revision-history reconstruction.

## Tables

Tables use a deterministic reading representation:

- cells in one row are separated by a tab (`\t`)
- rows are emitted as separate document paragraphs
- table rows remain in surrounding body order
- multiple paragraphs inside one cell are flattened into readable cell text
- nested table text is retained within the containing outer cell where possible

When general whitespace normalization is enabled, table cell boundary tabs are intentionally preserved even though ordinary horizontal whitespace is otherwise normalized.

## Lists and numbering

When `word/numbering.xml` is available and readable, TextExtractor resolves common Word list labels.

Supported numbering formats include:

- bullets
- decimal numbering
- lower/upper alphabetic numbering
- lower/upper Roman numerals
- basic nested `%1`, `%2`, and similar level patterns
- level start values
- `startOverride` values

Numbering counters are deterministic per Word `numId`. Deeper counters reset when returning to a shallower level.

If numbering definitions are malformed or a numbering format cannot be represented safely, paragraph text is retained without inventing a label. A stable `unsupportedDOCXFeature` warning is emitted where appropriate.

## Footnotes and endnotes

Footnotes and endnotes remain opt-in/opt-out through the existing public extraction options.

When included:

- Word separator and continuation records with IDs `-1` and `0` are filtered out
- readable note content follows the order in its OOXML part
- footnotes are appended after body content
- endnotes are appended after footnotes
- paragraph counts are recorded in document metadata

TextExtractor does not currently place notes at their reference positions in body text.

## Headers and footers

Headers and footers remain controlled by `includeDOCXHeadersAndFooters`.

When enabled:

- matching OOXML parts are processed in lexicographic archive-path order
- normalized duplicate paragraph text across header/footer parts is emitted once
- unique supplemental paragraphs are appended after body and notes
- emitted supplemental paragraph count is recorded in document metadata

This deliberately avoids pretending to reproduce section/page layout.

## Metadata

DOCX extraction includes additive metadata such as:

- `container = OOXML`
- `expandedArchiveBytes`
- `footnoteParagraphs`
- `endnoteParagraphs`
- `headerFooterParagraphs`

These additions do not change the existing public model or initializer requirements.

## Safety

All OOXML parts loaded by Phase 4 continue to use the Phase 1 archive budget machinery.

This includes `word/numbering.xml` in addition to the body, notes, headers, and footers. Per-entry expanded size, cumulative expanded bytes, archive entry count, and streamed extraction limits remain enforced.

## Intentional limitations

TextExtractor does not promise complete support for every OOXML feature. In particular, it does not reproduce:

- page layout or section geometry
- floating-object positioning
- styles or typography
- tracked-change history
- relationship-aware placement of notes
- every custom numbering format
- every drawing or embedded-object representation

Unsupported structures should degrade to clean readable text or a stable warning/error rather than silently producing misleading layout semantics.
