# TextExtractor Quality & Safety Roadmap

## Goal

Bring TextExtractor from a good MVP / early-production package to a package that is safe, predictable, well-tested, regression-resistant, and dependable for long-term use in Spokio and other apps.

The roadmap intentionally separates safety, correctness, verification, API hardening, and format fidelity. The order matters: resource safety and reproducible testing come before feature expansion.

## Guiding principles

1. Prefer safe failure over garbage extraction.
2. Bound memory and archive expansion before parsing untrusted documents.
3. Preserve deterministic behavior across platforms wherever possible.
4. Every parser behavior that matters to callers should be backed by fixtures.
5. New parsing logic should ship with both positive and negative tests.
6. Keep the package lightweight unless a dependency clearly improves correctness enough to justify its cost.
7. Do not improve fidelity by making malformed/adversarial input less safe.
8. Treat Spokio's normal-user document import as the primary product use case, while hardening enough that arbitrary user documents cannot easily destabilize the host app.

---

# Phase 0 — Establish the quality baseline

## Objective

Make the package continuously verifiable before changing parser behavior.

## Work

### CI

- Add GitHub Actions for pull requests and `master`.
- Run `swift test` on macOS.
- Build the package in release configuration.
- Build the demo application with code signing disabled.
- Fail the workflow on compiler warnings where practical.
- Keep CI deterministic and fast enough to run on every PR.

### Test organization

- Split tests by feature area rather than keeping most behavior in one file.
- Create reusable fixture helpers.
- Add fixture-path utilities that work reliably in Swift Package tests.
- Document how to add a regression fixture.

Suggested test structure:

```text
Tests/TextExtractorTests/
  CoordinatorTests.swift
  PlainTextExtractorTests.swift
  MarkdownTextExtractorTests.swift
  SubtitleExtractorTests.swift
  HTMLTextExtractorTests.swift
  RTFTextExtractorTests.swift
  DOCXTextExtractorTests.swift
  StringDecoderTests.swift
  StringNormalizerTests.swift
  SecurityAndLimitsTests.swift
  FixtureSupport.swift
```

### Fixture baseline

Drive the existing repository fixtures through XCTest instead of leaving them mostly for manual use.

For every supported extension, verify at minimum:

- extraction succeeds
- output is non-empty
- expected representative text appears
- output does not contain obvious markup/container garbage
- output remains stable enough to detect regressions

Avoid overfitting every fixture to one exact full output where platform behavior may vary. Use exact golden assertions only for deterministic code paths.

## Testing requirements

- CI must run the complete test suite.
- Existing fixtures must be exercised automatically.
- At least one failure-path test must exist for every extractor.

## Exit criteria

Phase 0 is complete when:

- every PR runs automated package tests
- release build succeeds in CI
- the existing fixture corpus is actually consumed by tests
- test failures clearly identify the format/component that regressed

---

# Phase 1 — Resource safety and hostile-input hardening

## Objective

Prevent malformed or adversarial input from causing excessive memory consumption, temporary-file leakage, or silent binary-to-text garbage conversion.

This is the highest-priority implementation phase.

## 1.1 DOCX archive expansion budgets

Add explicit archive limits to `TextExtractionOptions`.

Possible policy knobs:

```swift
maxInputBytes
maxArchiveEntryBytes
maxExpandedArchiveBytes
maxArchiveEntryCount
```

The exact public API can be refined, but the package must enforce both per-entry and cumulative expansion budgets.

### Required behavior

Before extracting a ZIP entry:

- inspect the entry's declared uncompressed size
- reject an entry that exceeds the configured per-entry budget
- track cumulative selected-entry expansion
- reject extraction once the total budget would be exceeded

During extraction:

- continue tracking actual emitted bytes
- abort if actual output exceeds the declared/budgeted threshold

Apply the budget to:

- `word/document.xml`
- footnotes
- endnotes
- headers
- footers
- any future OOXML part loaded into memory

### Error behavior

Add a stable package error such as:

```swift
case expandedContentTooLarge(actualBytes: Int, maxBytes: Int)
```

or another clearly named archive/resource-limit error.

Do not surface low-level ZIPFoundation errors for a policy-limit violation.

## 1.2 Temp cleanup correctness

Fix data-based DOCX materialization so the entire temporary directory is removed.

Requirements:

- one scoped temporary root per extraction
- cleanup in `defer`
- cleanup on both success and failure
- no orphaned UUID directories

Add a test that snapshots the relevant temp directory before and after repeated extraction.

## 1.3 Binary rejection before permissive legacy decoding

Harden `StringDecoder`.

Do not let ISO Latin-1 turn arbitrary binary data into apparently valid narration.

Add a binary-likelihood check before permissive fallback.

Signals may include:

- excessive NUL bytes
- excessive disallowed control characters
- implausible printable-character ratio
- known binary signatures

Keep the heuristic conservative to avoid rejecting legitimate legacy text.

Consider explicit Windows-1252 support if legacy text files matter to product usage.

## 1.4 Safer format sniffing

Do not classify every ZIP container as DOCX.

When extension evidence is missing, DOCX detection should verify at least:

- the archive opens successfully
- `word/document.xml` exists

Optionally verify content types / package relationships later.

## 1.5 URL/file safety

Add tests for:

- directory URL
- missing file
- unreadable file
- zero-byte file
- exactly-at-limit file
- one-byte-over-limit file

Normalize predictable policy errors into `TextExtractionError`.

## Security regression tests

Add cases for:

- highly compressible oversized DOCX XML
- oversized optional DOCX part
- archive with excessive entry count
- corrupt ZIP
- generic ZIP that is not DOCX
- binary `.txt`
- malformed UTF-16
- repeated failed DOCX extraction with no temp leak

## Exit criteria

Phase 1 is complete when:

- compressed size is no longer the only protection for DOCX
- archive expansion is bounded per-entry and cumulatively
- generic ZIP files are not claimed as DOCX
- binary input is rejected rather than narrated as Latin-1 garbage
- temporary DOCX files/directories are always cleaned up
- all safety behavior has regression tests

---

# Phase 2 — Error model, diagnostics, and API contracts

## Objective

Make package behavior predictable for application code and telemetry.

## 2.1 Normalize package-boundary errors

Decide and document whether callers should receive only `TextExtractionError`.

Recommended direction: normalize expected extraction failures into package-domain errors while preserving underlying debugging information where useful.

Examples to normalize:

- unreadable file
- ZIP open failure
- ZIP extraction failure
- malformed XML
- invalid RTF
- unsupported/malformed encoding

Do not erase useful context. Error cases may carry a concise reason/code while avoiding unstable low-level error strings as the only contract.

## 2.2 Machine-readable warnings

Evolve warnings from message-only values to stable categories.

Possible shape:

```swift
public struct TextExtractionWarning: Sendable, Equatable {
    public let code: Code
    public let message: String
}
```

Possible codes:

- malformedSubtitleTimestamp
- skippedDOCXFootnotes
- skippedDOCXEndnotes
- skippedDOCXHeader
- skippedDOCXFooter
- unsupportedDOCXFeature
- lossyEncodingFallback

This improves:

- tests
- telemetry
- UI messaging
- future recovery behavior

## 2.3 Segment identity contract

Do not use arbitrary source cue IDs directly as the only `Identifiable.id` guarantee.

Generate deterministic unique IDs for returned segments.

Preserve original subtitle cue IDs in metadata if useful.

Add tests with repeated cue IDs.

## 2.4 Extractor dispatch contract

Make extractor selection behavior explicit.

Current precedence should be reviewed for:

- extension match vs content validation
- custom extractor ordering
- multiple extractors claiming one extension
- whether custom extractor arrays replace or augment defaults

Possible future model:

```swift
DetectionResult(format, confidence, reason)
```

A confidence system is optional; what matters is making precedence intentional and tested.

## 2.5 Checked Sendable

Attempt to remove `@unchecked Sendable` from the coordinator.

If the compiler permits checked conformance, use it.

If not, document the exact blocker and keep the unsafe conformance narrowly justified.

## Exit criteria

Phase 2 is complete when:

- caller-visible failures are predictable
- warnings have stable machine-readable meaning
- segment IDs are guaranteed unique
- extractor precedence is documented and tested
- unnecessary unchecked concurrency annotations are removed

---

# Phase 3 — Parser correctness and format fidelity

## Objective

Improve output quality for normal real-world documents after safety and contracts are stable.

## 3.1 Plain text and encoding fidelity

Add a complete decoding matrix:

- UTF-8
- UTF-8 BOM
- UTF-16 LE BOM
- UTF-16 BE BOM
- legacy Latin-1 policy
- Windows-1252 if supported
- malformed sequences
- binary payload

Return/record the actual chosen encoding rather than generic metadata such as `encoding: auto`.

## 3.2 Markdown correctness

Keep the parser lightweight unless real fixture failures prove the regex approach inadequate.

Improve common speech-oriented cases:

- Setext headings
- task lists
- escaped formatting characters
- reference links and definitions
- autolinks
- indented code blocks
- longer/custom fenced code markers
- nested lists and blockquotes
- tables
- inline code edge cases

Prioritize patterns observed in real imported files rather than attempting full CommonMark compliance for its own sake.

## 3.3 Subtitle quality

Improve real caption narration.

### Rolling-caption deduplication

Current duplicate removal handles exact consecutive duplicates only.

Add an overlap-aware strategy for captions such as:

```text
We are
We are going
We are going home
```

The output should avoid repeatedly narrating prefixes while preserving genuinely changed dialogue.

Make this behavior testable and conservative.

### Timestamp validation

Define lenient vs strict policy.

Recommended default:

- retain usable text from malformed cues when safe
- emit a warning when timing cannot be parsed
- reject only structurally unusable subtitle input

### VTT coverage

Add fixtures for:

- NOTE
- STYLE
- REGION
- cue settings
- cue IDs
- multiline cues
- malformed timestamp lines

## 3.4 HTML consistency

Separate tests for:

- Apple `NSAttributedString` path
- lightweight fallback path

Improve fallback behavior only where fixtures prove material quality gains.

Add coverage for:

- comments
- malformed tags
- quoted `>` attributes
- nested block elements
- tables
- lists
- typography entities
- script/style/noscript

Document that fallback semantics are intentionally approximate.

## 3.5 RTF robustness

Add real fixture-driven RTF tests:

- formatting
- Unicode text
- paragraphs
- malformed input
- larger files

Normalize invalid-RTF failure behavior.

## Exit criteria

Phase 3 is complete when:

- each text-like format has real-world fixture coverage
- common encoding behavior is deterministic and documented
- subtitle output avoids obvious repeated rolling-caption narration
- HTML fallback behavior is directly tested
- parser improvements are driven by regression fixtures, not only handcrafted examples

---

# Phase 4 — DOCX correctness and semantic quality

## Objective

Turn DOCX from basic OOXML text extraction into a dependable reading-oriented parser without trying to reproduce Word layout.

## 4.1 Define reading semantics

Document what TextExtractor promises for DOCX.

Recommended contract:

- readable body text in logical document order
- paragraph boundaries preserved
- explicit breaks preserved
- tables flattened predictably
- deleted tracked text excluded
- visible inserted text retained
- field instructions omitted while visible field result text is retained when available
- optional notes/headers/footers included according to options
- no promise of layout reproduction

## 4.2 Parser state correctness

Replace boolean ignore state with depth-aware state or an element stack for:

- deleted content
- instruction text
- any future nested ignored OOXML regions

Add deliberately nested XML tests.

## 4.3 Table semantics

Make table behavior intentional.

Recommended reading-oriented representation:

- cells separated by a tab or configurable cell separator
- rows separated by a newline/paragraph separator
- surrounding body flow preserved

Do not merely assert that cell strings are present; test exact structural output.

## 4.4 Lists and numbering

Support commonly encountered Word list labels by reading numbering definitions where practical.

Priority:

- bullets
- decimal lists
- basic nested numbering

If full numbering support proves disproportionately complex, explicitly document the limitation and preserve clean text without misleading labels.

## 4.5 Footnotes and endnotes

Improve semantics beyond blindly appending every parsed note paragraph.

At minimum:

- filter separator/continuation metadata notes
- preserve deterministic note order
- distinguish footnotes and endnotes in metadata/warnings if needed

Future option: place notes at reference points, but only if product value justifies the complexity.

## 4.6 Headers and footers

Improve deterministic ordering and avoid duplicate repeated content where practical.

Potential policy choices:

- unique header/footer text only
- section-order extraction
- explicit metadata segments

Choose one behavior and test it.

## 4.7 OOXML edge coverage

Add regression fixtures for:

- tables
- lists
- headers and footers
- footnotes/endnotes
- tracked changes
- hyperlinks
- explicit tabs/breaks
- content controls
- drawings/text boxes where readable text is present
- malformed XML
- missing document.xml
- unusual namespace prefixes

Not every OOXML feature must be supported; unsupported behavior should be deliberate rather than accidental.

## Exit criteria

Phase 4 is complete when:

- DOCX table output has defined semantics
- nested parser state is safe
- common Word lists are handled or explicitly scoped out
- note/header/footer behavior is deterministic
- a rich DOCX fixture suite protects reading-order behavior
- all archive safety guarantees from Phase 1 remain enforced

---

# Phase 5 — Reliability, fuzzing, and performance

## Objective

Catch parser assumptions that ordinary unit tests miss and establish performance expectations.

## 5.1 Mutation/fuzz-style testing

Create lightweight mutation tests around text parsers:

- truncate inputs at arbitrary positions
- insert invalid bytes
- duplicate delimiters
- remove closing markup
- randomize line endings
- randomize harmless whitespace

For DOCX:

- missing optional entries
- corrupt selected entries
- invalid XML fragments
- reordered archive entries
- duplicate OOXML parts

The invariant is not always "extraction succeeds." The invariant is:

- no crash
- no unbounded allocation
- no hang
- deterministic error/warning behavior

## 5.2 Performance benchmarks

Add representative benchmarks outside normal unit-test assertions or in a dedicated benchmark harness.

Measure:

- TXT decode/normalize
- Markdown cleanup
- large subtitles
- large HTML
- DOCX body extraction
- DOCX with optional parts

Track:

- wall time
- peak-ish memory where practical
- expanded archive bytes
- segment count

Avoid brittle microbenchmarks in CI, but establish rough regression thresholds for pathological slowdowns.

## 5.3 Large-file tests

Add generated fixtures around configured limits rather than checking only tiny samples.

Cases:

- just below input limit
- exactly at input limit
- just over input limit
- many subtitle cues
- many Markdown paragraphs
- DOCX with large but permitted XML
- DOCX exceeding expanded-content budget

## 5.4 Repeated extraction stability

Run repeated extraction loops to expose:

- temp-file leaks
- retained memory
- state leakage between calls
- concurrency issues

## Exit criteria

Phase 5 is complete when:

- mutated malformed inputs do not crash or hang the package
- size-limit behavior is tested at boundaries
- repeated extraction leaves no temp artifacts
- performance expectations are documented
- obvious algorithmic regressions are detectable

---

# Phase 6 — Production polish and release discipline

## Objective

Make TextExtractor easy to consume independently and safe to evolve without surprising Spokio.

## 6.1 Public documentation

Document:

- supported formats
- supported platforms
- format-specific guarantees
- intentional limitations
- resource limits
- warning behavior
- error behavior
- threading/concurrency guidance
- examples for custom extractors

## 6.2 Versioning policy

Adopt semantic versioning expectations.

Clarify what counts as breaking:

- public model changes
- changed default options
- changed extraction semantics that materially alter output
- removed format support

Treat parser quality fixes as non-breaking when they correct clearly erroneous behavior, but document material output changes in release notes.

## 6.3 Changelog/release notes

Add a changelog once the package begins tagged releases.

Record:

- parser correctness fixes
- changed defaults
- new supported formats
- safety-limit changes
- output-affecting behavior changes

## 6.4 Spokio integration verification

Because Spokio consumes a synced copy of TextExtractor, add a release/sync checklist:

1. TextExtractor CI green.
2. Package fixture suite green.
3. Tag/revision chosen.
4. Sync into Spokio.
5. Verify revision lock.
6. Run Spokio document-import tests.
7. Manually sanity-check representative imports in Spokio.

Consider automating drift detection between the standalone package and Spokio's vendored package copy.

## Exit criteria

Phase 6 is complete when:

- package behavior and limitations are documented
- release/versioning rules exist
- Spokio synchronization is repeatable and verifiable
- standalone and vendored copies cannot silently drift

---

# Recommended execution order

| Priority | Phase | Why |
| --- | --- | --- |
| P0 | Phase 0 — Baseline/CI | Every later change needs reliable verification |
| P0 | Phase 1 — Safety | Prevent memory/resource failures on user-controlled documents |
| P1 | Phase 2 — Contracts | Stabilize errors, warnings, IDs, and dispatch before deeper parser changes |
| P1 | Phase 3 — Text-format correctness | Improve common user-visible output quality |
| P1 | Phase 4 — DOCX fidelity | Highest-complexity format deserves isolated correctness work |
| P2 | Phase 5 — Fuzz/performance | Harden long-tail behavior and detect regressions |
| P2 | Phase 6 — Release polish | Make maintenance and Spokio integration dependable long-term |

---

# Quality target after completion

The package should be able to claim all of the following:

- safe bounded handling of user-controlled document input
- no known archive-expansion or temporary-file resource leaks
- deterministic domain-level failure behavior
- automated CI on every change
- fixture-driven tests for every supported format
- strong malformed-input and boundary coverage
- clean text extraction for normal real-world TXT, Markdown, subtitle, HTML, RTF, and DOCX documents
- explicit and documented DOCX reading semantics
- predictable cross-platform behavior where platform APIs differ
- unique segment identity and structured warnings
- checked concurrency safety where possible
- repeatable synchronization into Spokio without silent drift

At that point TextExtractor moves from "good MVP / early production" to a package that can reasonably be treated as mature application infrastructure.