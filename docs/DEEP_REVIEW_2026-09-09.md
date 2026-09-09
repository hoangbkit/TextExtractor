# TextExtractor Deep Review — 2026-09-09

## Scope

This review covers `hoangbkit/TextExtractor` at `master` commit `30ebbe1dab0a7d25a6db7810b89ba222a204ae83`.

The review focuses on:

- public API design
- format detection and dispatch
- text decoding and normalization
- TXT / Markdown / SRT / VTT / RTF / HTML / DOCX extraction
- DOCX archive and XML handling
- correctness and failure behavior
- memory / resource safety
- concurrency and Swift 6 readiness
- test quality and fixture coverage
- package/release engineering
- maintainability and future extensibility

No implementation changes are included in this PR.

## Executive summary

TextExtractor has a good small-package shape and is already useful for Spokio's document-to-TTS import path. The package has a compact public API, a clear extractor protocol, sensible normalization defaults, useful subtitle segmentation, and lightweight dependencies.

The current code is best described as **good MVP / early production quality for trusted user documents**, but it is **not yet hardened for arbitrary or adversarial document input**. The largest gap is DOCX archive expansion: `maxInputBytes` limits the compressed input but extracted ZIP entries are accumulated into memory without an uncompressed-size or total-expansion bound. A small malicious DOCX can therefore bypass the intended 50 MB protection and cause severe memory pressure.

The second major concern is verification. The repository contains a useful fixture corpus for every supported extension, but the actual XCTest suite mostly uses short inline samples and synthetic DOCX files. There is no CI workflow in the repository, so regressions in parsers, platform behavior, or package builds are easy to miss.

### Overall assessment

| Area | Assessment | Notes |
| --- | --- | --- |
| API shape | Good | Small, understandable, extensible |
| Architecture | Good | Extractor protocol keeps formats isolated |
| TXT | Good MVP | Encoding validation needs hardening |
| Markdown | Fair-Good | Regex approach is pragmatic but intentionally incomplete |
| SRT/VTT | Good MVP | Useful segments; validation/dedup can improve |
| HTML | Fair-Good | Apple parser is capable; fallback is heuristic |
| RTF | Good on Apple platforms | Thin NSAttributedString wrapper |
| DOCX | Fair | Good basic OOXML extraction, but archive safety and semantic fidelity need work |
| Error model | Fair | Useful domain errors, but many lower-level errors still escape |
| Concurrency | Good with caveat | Mostly immutable; `@unchecked Sendable` should be revisited |
| Tests | Fair-Poor | Happy-path coverage exists; fixture and failure coverage are thin |
| CI / release engineering | Weak | No repository CI currently |
| Security/resource hardening | Needs work | DOCX expansion limits are the top priority |

## Architecture review

### What is working well

`TextExtractor` is intentionally small. The main coordinator owns an array of `TextFormatExtractor` implementations and delegates extraction based on extension or content sniffing. This is a good boundary: adding a new format does not require modifying the internals of every existing parser.

The public model is also appropriately lightweight:

- `TextExtractionFormat` identifies the source family.
- `TextExtractionOptions` centralizes policy knobs.
- `ExtractedTextDocument` provides normalized text plus optional segments, metadata, and warnings.
- `ExtractedTextSegment` is a useful fit for subtitle/timed formats.
- `TextExtractionError` gives callers a domain-oriented error vocabulary.
- `TextFormatExtractor` enables custom extractors and isolated testing.

The package also avoids unnecessary heavy frameworks. ZIPFoundation is the only package dependency, which is reasonable for DOCX.

### Architectural limitation: extractor precedence is implicit

`extractor(forFileName:data:)` first chooses the first extractor matching the file extension. Only when no extension matches does it call `canExtract` across extractors.

Consequences:

1. A mislabeled file is trusted by extension before content validation.
2. Multiple custom extractors supporting the same extension are resolved only by array order.
3. `canExtract` has inconsistent value across implementations because it is skipped for known extensions.
4. Passing a custom `extractors:` array replaces the default set entirely rather than augmenting it.

This is not a current blocker, but future format growth will make dispatch policy increasingly important.

Recommended direction: introduce an explicit detection result / confidence model or at minimum require extension-matched extractors to validate recognizable container signatures where practical.

## Public API review

### Strengths

- Defaults are practical for TTS use.
- `maxInputBytes` is a good safety concept.
- subtitle settings and DOCX inclusion settings are exposed without leaking parser internals.
- models conform to `Sendable` and `Equatable`, which helps testing and async use.
- warnings allow partial success for optional DOCX components.

### Improvement opportunities

#### 1. `@unchecked Sendable` should be removed if possible

`TextExtractor` is a final class whose state is established at initialization and never mutated. Its stored extractor protocol also requires `Sendable`. The package should attempt checked `Sendable` conformance under modern Swift and use `@unchecked` only if the compiler proves there is a real blocker.

Unchecked conformance is a long-term maintenance liability because later mutable state could be added without compiler protection.

#### 2. Warning values are not machine-readable

`TextExtractionWarning` contains only a message. This is fine for UI display but weak for telemetry, tests, or recovery logic.

A future version could add a stable warning code/category while retaining the human-readable message.

#### 3. Error normalization is incomplete

The package defines useful `TextExtractionError` cases, but operations such as URL resource lookup, `Data(contentsOf:)`, ZIP extraction, file writes, and RTF decoding may throw Foundation/ZIPFoundation errors directly.

Callers therefore cannot assume failures are `TextExtractionError`.

This should either be documented explicitly or normalized consistently at the package boundary.

#### 4. Segment IDs are not guaranteed unique

Subtitle cue IDs are copied from source files. Malformed or hand-authored subtitles can repeat cue IDs. Because `ExtractedTextSegment` is `Identifiable`, consumers may naturally assume uniqueness in SwiftUI collections.

Consider preserving the source cue ID in metadata and generating a deterministic unique segment ID.

## Input size and resource safety

### HIGH — DOCX compressed-size limit does not bound expanded content

`TextExtractor` checks URL file size and `Data.count` against `maxInputBytes`. This protects direct input size.

However DOCX is a ZIP container. `DOCXTextExtractor.readEntry` extracts each selected entry and appends every chunk into an unbounded `Data` value. There is no check on:

- individual entry uncompressed size
- cumulative extracted bytes
- compression ratio
- number of header/footer entries

A small compressed archive can therefore expand far beyond `maxInputBytes` after passing the initial guard.

Impact:

- memory exhaustion
- process termination
- denial of service from an imported document

Recommended fix:

- add `maxExpandedBytes` / `maxArchiveEntryBytes` policy, or reuse a clearly documented total extraction budget
- inspect ZIP entry uncompressed sizes before extraction
- track cumulative extracted bytes across document XML, footnotes, endnotes, headers, and footers
- abort before or during extraction once the budget is exceeded
- add a regression test with a highly compressible oversized entry

This should be the first hardening change.

### MEDIUM — temporary directory leak for data-based DOCX extraction

When DOCX extraction starts from `Data`, `materializeArchiveURL` creates:

`TextExtractor-<UUID>/document.docx`

The defer block deletes `document.docx`, but not its parent UUID directory. Repeated data-based extraction leaves empty temporary directories behind.

Recommended fix: return both the materialized URL and cleanup root, or create a temporary file directly, then remove the complete temporary directory in `defer`.

### MEDIUM — text encoding fallback accepts effectively arbitrary bytes

`StringDecoder` tries UTF variants and then ISO Latin-1. ISO Latin-1 can map essentially every byte value to Unicode, meaning random binary content with a text-like extension can often produce a string rather than `unreadableTextEncoding`.

This makes the error case much less useful than it appears and can turn binary corruption into garbage narration.

Recommended fix:

- add a binary/NUL/control-character heuristic before Latin-1 fallback
- consider Windows-1252 explicitly if legacy documents matter
- record the selected encoding instead of returning metadata value `encoding: auto`
- add UTF-16, Latin-1, Windows-1252, malformed, and binary fixture tests

## Text normalization review

`StringNormalizer` has a sensible TTS-oriented policy: normalize newlines, strip NBSP/zero-width space, collapse horizontal whitespace, preserve paragraphs by default, and remove unsafe low control characters.

### Issues

#### Control-character filtering is incomplete

The filter retains every scalar with value >= 32. That includes DEL and C1 control characters. A Unicode general-category based filter would better express the intent.

#### Custom paragraph separator can be normalized away

DOCX/subtitle paths join content using `paragraphSeparator`, then run normalization. When `preserveParagraphs` is true, three or more consecutive newlines are collapsed to two. Therefore a custom separator such as `"\n\n\n"` is not preserved.

Either document that separators are inputs to normalization, or normalize components before joining them with the requested separator.

## Plain text extraction

The implementation is clean and appropriately minimal.

Main risk is inherited from `StringDecoder`: binary data with `.txt` or `.text` extension can be accepted as Latin-1 garbage.

Recommended additional tests:

- UTF-8 with/without BOM
- UTF-16 LE/BE with BOM
- UTF-16 without BOM if intentionally supported
- Latin-1 / Windows-1252 policy
- embedded NUL bytes
- binary payload labeled `.txt`
- empty input
- maximum-size boundary

## Markdown extraction

The Markdown parser is intentionally heuristic and suitable for speech-oriented cleanup when inputs are normal Markdown.

### Good choices

- YAML front matter removal
- optional fenced-code removal
- link URL removal while retaining link text
- image alt-text retention
- list marker / heading / quote cleanup
- inline emphasis cleanup
- HTML tag cleanup and entity decoding

### Limitations to document or test

The regex strategy does not fully implement Markdown grammar. Important edge cases include:

- nested brackets / parentheses in links
- reference definitions
- autolinks
- indented code blocks
- fenced blocks with unusual fence lengths/nesting
- task list markers
- Setext headings
- nested blockquotes
- complex tables
- escaped Markdown punctuation
- inline code containing backticks
- raw HTML with malformed tags

This does not necessarily justify adding a full Markdown dependency. For a TTS package, the current lightweight strategy is defensible. The important next step is fixture-driven behavior tests so improvements do not accidentally make common documents worse.

## Subtitle extraction

The SRT/VTT design is one of the stronger parts of the package because it returns both readable text and timed segments.

### Strengths

- handles CRLF normalization
- parses hour and minute timestamp forms
- understands VTT cue settings after end time
- removes common subtitle markup
- decodes common HTML entities
- skips VTT header / NOTE blocks
- removes exact consecutive duplicates by default

### Limitations

#### Duplicate removal is exact, not “near duplicate”

The helper is named `removeNearDuplicateConsecutiveSegments`, but it only compares lowercased whitespace-normalized strings for equality.

Rolling captions often look like:

- `We are`
- `We are going`
- `We are going home`

These still produce repeated narration.

Either rename the helper to match behavior or implement overlap-aware rolling-caption deduplication.

#### Malformed timestamps are accepted as segments

Any line containing `-->` can become a cue. If timestamp parsing fails, the segment is still emitted with nil times.

That may be a reasonable lenient policy, but it should be deliberate and tested. Warnings would be useful for malformed timestamps.

#### Cue IDs can repeat

As noted in the API section, source IDs are not guaranteed unique.

#### Regex tag stripping can remove literal text

`<...>` and `{...}` are removed as formatting. This is useful for normal subtitle files but can delete legitimate dialogue containing those characters.

## HTML extraction

On Apple platforms, HTML is first processed through `NSAttributedString`, which generally provides significantly better results than regex stripping. The basic parser is a useful fallback.

### Risks / limitations

#### Output can vary by platform / OS implementation

The Apple `NSAttributedString` HTML importer and the lightweight fallback do not have identical semantics. The same input can therefore produce different normalized text depending on platform availability and importer behavior.

Tests should distinguish:

- Apple attributed-string path
- fallback path

The current `testHTMLExtractionFallbackReadableText` name is misleading on macOS/iOS because the test normally exercises `NSAttributedString`, not the fallback.

#### Fallback parser is intentionally shallow

Regex stripping cannot correctly model malformed HTML, embedded `>` characters in quoted attributes, unusual comments, or complex DOM semantics.

#### Named entity support is limited

Numeric entities are handled generically, but only a small fixed list of named HTML entities is decoded by the fallback decoder.

For common prose this is probably sufficient, but fixtures should include typography and less-common entities to establish expected behavior.

## RTF extraction

RTF extraction is appropriately delegated to `NSAttributedString` on Apple platforms.

The package currently declares only macOS 13+ and iOS 16+, so the non-Apple fallback error path is mostly future-facing.

Recommended improvements:

- wrap invalid RTF decode errors consistently if the package wants domain-only errors
- add malformed RTF tests
- add real-world fixture tests rather than only one short inline RTF string

## DOCX extraction

DOCX is the most complex and highest-risk component.

### What it already does well

- uses ZIPFoundation instead of implementing ZIP parsing
- requires `word/document.xml`
- parses body paragraphs
- captures text runs
- handles tabs and explicit breaks
- ignores deleted text and field instruction text
- optionally includes footnotes and endnotes
- optionally includes headers and footers
- treats optional-part failures as warnings
- disables XML external entity resolution

These are good MVP decisions.

### HIGH — ZIP expansion safety

See the resource safety section. This is the highest-priority issue in the package.

### MEDIUM — generic ZIP signature is treated as DOCX during sniffing

`DOCXTextExtractor.canExtract` returns true for any `PK\x03\x04` file when there is no recognized extension.

That means an arbitrary ZIP can be selected as DOCX and then fail with “Missing word/document.xml” rather than remaining unsupported.

Recommended detection should verify at least one DOCX-specific entry, such as `word/document.xml`, before claiming the format when extension evidence is absent.

### MEDIUM — XML ignore state uses booleans rather than depth

`isIgnoringDeletedText` and `isIgnoringFieldCode` are booleans. For nested/overlapping XML elements, ending one ignored element can reset the boolean even if an outer ignored context remains active.

OOXML is structured enough that this may be uncommon, but depth counters or an element stack would be safer.

### MEDIUM — table structure is not actually preserved

The parser adds a tab when entering `tc` only if the current paragraph buffer is already non-empty. In normal WordprocessingML, each cell contains its own `w:p`, and each paragraph flushes independently. As a result, table cells are generally emitted as separate paragraphs rather than reliable tab-separated rows.

The current DOCX test checks that `Cell A` and `Cell B` exist but does not assert row/cell structure.

For TTS, flattening cells may be acceptable. The package should either:

- define flattening as intentional behavior, or
- introduce explicit table row/cell parsing and separators.

### Footnote/endnote semantics are flattened

All note paragraphs are appended after body text rather than inserted at reference locations. Built-in separator entries are not explicitly filtered by note type/ID.

This is acceptable for “extract all readable text,” but not for faithful reading order.

### Other unsupported DOCX semantics

Expected MVP limitations include:

- comments
- text inside some drawing/embedded object structures
- tracked-change semantics beyond deletion filtering
- hyperlinks as URLs
- section-aware header/footer ordering
- numbered/bulleted list labels generated from numbering definitions
- table hierarchy
- content controls / alternate content nuances
- document properties as metadata

These should remain explicit non-goals unless Spokio needs them.

## Format detection review

Current detection is primarily extension-based.

| Format | Extension detection | Content sniffing |
| --- | --- | --- |
| TXT | Yes | No |
| Markdown | Yes | No |
| SRT | Yes | No |
| VTT | Yes | No |
| RTF | Yes | No |
| HTML | Yes | No |
| DOCX | Yes | ZIP signature only |

This is predictable for user-imported files, but weak for files with missing/wrong extensions.

A future detection layer could use conservative signatures:

- RTF: `{" + "\\rtf"` prefix
- HTML: doctype/html/body heuristics
- VTT: `WEBVTT` header
- SRT: timestamp-arrow pattern
- DOCX: ZIP plus `word/document.xml`
- text/markdown: only after binary rejection

Avoid overly aggressive sniffing; false positives are worse than requiring a valid extension in many app workflows.

## Test suite review

### Current strengths

The XCTest suite covers representative happy paths for:

- UTF-8 BOM text normalization
- readable Markdown extraction
- SRT segments and timestamps
- VTT cue settings and exact duplicate removal
- HTML readable output
- unsupported extension error
- RTF on Apple platforms
- DOCX body text
- DOCX table text presence
- DOCX footnotes/endnotes
- optional DOCX header extraction

This gives a good smoke-test baseline.

### Major gap — repository fixtures are not systematically tested

The repository includes short/medium/long fixtures for:

- TXT
- MD / MARKDOWN
- SRT
- VTT
- RTF
- HTML / HTM
- DOCX

But the two test files do not run the fixture corpus as a matrix. Most parser coverage uses inline strings or synthetic archives.

The fixture corpus should become the backbone of regression testing.

Recommended fixture strategy:

1. Add fixture resources to the test target or resolve them deterministically from the package checkout.
2. For every file, assert extraction succeeds and produces non-empty output.
3. Add format-specific golden assertions for important structure.
4. Add corrupted/malformed counterparts.
5. Add real-world fixtures for edge cases instead of only generated samples.

### Missing test categories

- `maxInputBytes` boundaries
- DOCX expanded-size limits
- DOCX malformed ZIP / non-DOCX ZIP
- cleanup of temporary files/directories
- empty document behavior
- custom extractor precedence
- duplicate extractor formats/extensions
- extensionless detection
- mislabeled files
- encoding matrix
- binary text rejection
- normalization option combinations
- custom paragraph separators
- raw Markdown mode
- keeping Markdown code blocks
- VTT NOTE / STYLE / REGION behavior
- malformed subtitle timestamps
- repeated subtitle cue IDs
- rolling-caption duplicate behavior
- HTML fallback specifically
- HTML entity matrix
- malformed RTF
- malformed DOCX optional parts producing warnings
- DOCX deleted text / fields
- large real-world documents
- performance / memory tests
- concurrency stress

## CI and release engineering

The repository has no `.github/workflows` directory at the reviewed commit.

For a package embedded into a shipping app, CI should be considered required before deeper parser work.

Suggested minimum CI:

- `swift test` on a supported macOS runner
- build/test under the current stable Xcode toolchain
- build with the next/newer Swift language mode where practical
- iOS simulator compile/test for Apple-framework code paths
- fixture regression suite

Optional later gates:

- Swift 6 strict concurrency build
- memory/performance regression tests
- sanitizer runs for parser-heavy changes

## Packaging and documentation

### Good

- Swift tools 5.9
- explicit macOS 13 / iOS 16 support
- one focused library product
- one focused production dependency
- demo application included
- README clearly positions the package for TTS-oriented readable text

### Improvements

- document malformed-input behavior and error guarantees
- document that Markdown/HTML/DOCX are readability extractors, not semantic/rendering-preserving parsers
- document archive expansion limits once added
- explain extractor replacement behavior when using `init(extractors:)`
- add public API doc comments
- consider a changelog/versioning policy before reuse grows across apps

## Prioritized findings

| Priority | Finding | Impact |
| --- | --- | --- |
| P1 | DOCX expanded ZIP data is unbounded | Memory exhaustion / denial of service |
| P1 | Fixture corpus is not systematically executed and no CI exists | Regressions can ship unnoticed |
| P1 | Binary data can fall through to Latin-1 decoding | Corrupt/binary input can become garbage text |
| P2 | Data-based DOCX leaves empty temp directories | Persistent resource leak |
| P2 | Generic ZIP signature is enough for DOCX sniffing | False-positive format detection |
| P2 | DOCX parser ignore state is boolean, not depth-aware | Edge-case incorrect text inclusion |
| P2 | DOCX table semantics are not preserved/tested | Reading-order / structure quality |
| P2 | HTML behavior differs between Apple importer and fallback | Cross-path output inconsistency |
| P2 | Subtitle “near duplicate” logic only handles exact duplicates | Repetitive narration on rolling captions |
| P2 | Lower-level errors are not consistently normalized | Less predictable caller behavior |
| P3 | `@unchecked Sendable` weakens compiler guarantees | Future concurrency maintenance risk |
| P3 | Warning values lack stable codes | Harder telemetry/testing/recovery |
| P3 | Segment IDs can repeat | Potential SwiftUI identity problems |
| P3 | Markdown regex parser has known grammar gaps | Edge-case readability degradation |
| P3 | Custom paragraph separators may be normalized away | Option semantics are surprising |

## Recommended implementation phases

### Phase 1 — safety and correctness hardening

Goal: make extraction safe for arbitrary user-imported files.

- bound DOCX uncompressed entry and cumulative expansion size
- reject pathological compression/oversized archive content before allocation
- fix DOCX temporary-directory cleanup
- improve extensionless DOCX detection to require DOCX structure
- add binary-text rejection before Latin-1 fallback
- decide and document domain-error wrapping policy
- add focused regression tests for every Phase 1 issue

Exit criteria:

- compressed DOCX cannot bypass memory budget
- repeated data-based DOCX extraction leaves no temp artifacts
- random binary data labeled as text is rejected
- non-DOCX ZIP is not positively identified as DOCX

### Phase 2 — fixture-driven regression suite and CI

Goal: make existing behavior measurable and stable.

- execute all existing fixtures in automated tests
- add golden/structural expectations where useful
- add malformed and adversarial fixtures
- add GitHub Actions for package tests and Apple build coverage
- add option-combination tests
- add memory/performance smoke tests for large fixtures

Exit criteria:

- every committed fixture is exercised
- PRs cannot merge with failing package tests
- both pure-Foundation and Apple-framework paths have meaningful coverage

### Phase 3 — parser quality

Goal: improve output quality without bloating the package.

- make DOCX XML ignore state depth-aware
- define and test DOCX table flattening or preserve row/cell structure
- filter/label DOCX note types and improve note handling
- improve subtitle rolling-caption deduplication
- validate subtitle timestamps and emit warnings for recoverable malformed cues
- expand HTML entity handling if real fixtures justify it
- improve high-value Markdown edge cases based on fixture failures

Exit criteria:

- common real-world DOCX/subtitle/Markdown fixtures produce stable speech-friendly reading order
- known parser limitations are explicitly documented

### Phase 4 — API and Swift 6 cleanup

Goal: improve maintainability for reuse outside Spokio.

- replace `@unchecked Sendable` with compiler-checked conformance if possible
- clarify custom extractor augmentation/replacement behavior
- introduce stable warning codes if consumers need them
- ensure segment identity is deterministic and unique
- add public API documentation
- test under strict concurrency / newer Swift language mode

## Suggested acceptance bar before calling the package “hardened production”

1. No unbounded decompression or parser allocation from a bounded input file.
2. All temporary resources are deterministically cleaned up.
3. Corrupt/binary inputs fail predictably.
4. Existing fixture corpus runs in CI.
5. Malformed inputs have dedicated negative tests.
6. DOCX table/note behavior is explicitly specified.
7. Subtitle dedup behavior is specified and regression-tested.
8. Public error behavior is documented.
9. Swift concurrency checks do not depend on unnecessary unchecked conformance.
10. Large-file extraction has at least basic performance/memory regression coverage.

## Conclusion

TextExtractor is a strong foundation for a lightweight, local, TTS-oriented document importer. Its architecture should be kept simple; there is no need to turn it into a full document-rendering engine.

The next work should focus less on adding formats and more on **hardening the current seven formats**. In particular, DOCX expansion limits, binary decoding validation, fixture-driven tests, and CI would materially improve reliability without making the package much larger.

After those changes, the package would be in a much stronger position to act as the canonical reusable TextExtractor implementation for Spokio and other apps.