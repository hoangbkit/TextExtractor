# TextExtractorWeb: Pass 1 API and fixture contract

Tracking: [TextExtractor issue #5](https://github.com/hoangbkit/TextExtractor/issues/5).

## Scope boundary

This deliverable is an **independent, opt-in SwiftPM product**, `TextExtractorWeb`. In Pass 1 the package contains semantic **value types, a pure renderer, baseline model tests, and offline fixtures**; it does not yet include a functioning `WebArticleExtractor`. Parsing and SwiftReadability/SwiftSoup dependencies belong to Pass 2.

**Do not modify `Sources/TextExtractor/**`, existing `TextExtractor` public types, format dispatch, `HTMLTextExtractor`, options, or semantics.** `Package.swift` may add a separate product/target and target-scoped dependencies. Future app integrations and a web fetcher are out of scope.

## Public value types (`import TextExtractorWeb`)

- `WebArticleBlockKind`: `paragraph`, `heading(level: 1...6)`, `listItem`, `quote`, `code`, `table`, `caption`, `preservedContent`.
- `WebArticleBlock`: immutable semantic `id`, `kind`, `text`; throws for empty IDs/text or invalid heading levels.
- `WebArticleResult`: immutable `title`, `sourceURL`, ordered `blocks` and `metadata`. `text` is a **computed convenience projection** of `blocks`, not a second persisted copy.
- `WebArticleTextRenderer.render`: pure formatting of finalized blocks, joining adjacent block text with exactly `\n\n`. Internal line breaks are preserved (not reclassified); no TTS chunking occurs.
- Model values conform to `Hashable`, `Codable`, `Sendable` where appropriate. Decoding applies the same ID/title/text validation as construction.
- `WebArticleModelError`: invalid result/value errors. Parser errors and cancellation are **separate** and will be specified in Pass 2.

### Identity and ordering

Blocks appear in source reading order after main-article extraction and normalization. IDs are unique within one result and deterministic across repeated extractions of the **same HTML and options**, including repeated occurrences of identical text. IDs **are not** promised stable across edited HTML, changed segmentation or parser-version updates. Avoid Swift `hashValue`, random UUIDs or unstable DOM-object identities. The normalization pass owns actual ID generation; Pass 1 only validates nonempty and unique IDs.

A semantic block is not a TTS chunk. List items, headings and paragraphs should remain separate even when short; code and table blocks can retain their intentional internal newlines. Any later filtering for narration must not rewrite canonical classification or order.

### Conversion invariants

1. Extract the main article HTML with SwiftReadability (Pass 2).
2. Walk the cleaned DOM with SwiftSoup **in source order**, keeping kind information before flattening. Distinguish `h1`–`h6`, `p`, `li`, `blockquote`, `pre`/`code`, `table`, `figcaption`; conservatively preserve other meaningful text as `preservedContent`.
3. Normalize whitespace and decode entities in a bounded pass without destroying legitimate code/table breaks or structural boundaries. Do not emit a `p` again when its enclosing `li` or `blockquote` already owns its content.
4. Assign deterministic occurrence-distinct IDs to the finalized blocks.
5. Produce `WebArticleResult`; its `text` comes **only** from those finalized blocks. Never independently generate the plain text by another parser path.

There is no PDF-style geometry, OCR evidence, complex inferred paragraph merging or global read/skip policy here.

### Metadata

The `metadata` dictionary uses stable keys:

| Key | Meaning |
| --- | --- |
| `author` | Article byline when exposed |
| `siteName` | Publication/site name when exposed |
| `language` | Original article language tag when exposed |
| `publishedTime` | Publisher-provided publication timestamp when exposed |

Missing/empty values should be omitted. Do not infer publication timestamps or authors.

### HTML input, limits, and errors (implementation contract for Pass 2)

- `WebArticleExtractor.extract(html: Data, sourceURL: URL)` will be a **synchronous extraction from supplied HTML**, not a downloader. Caller performs any network request.
- Accept actual HTTP/HTTPS document URLs as sources and reject unsupported schemes. No `URLSession`, cookies, authentication, JavaScript engine or paywall bypass.
- Use a bounded input-size default (proposed 5 MiB) and enforce before decoding, with cancellation checks while processing. Avoid retaining duplicate copies of large HTML in the result.
- Prefer correct UTF-8, recognize a relevant BOM/declared charset where feasible, and use a documented conservative Windows-1252 fallback; invalid/binary material must fail safely.
- Return a typed extraction error for oversized input, unsupported URL, unsupported encoding, or lack of a credible main article. **Do not treat a navigation-only page as a successful article**.
- Retaining source raw HTML is **not** part of `WebArticleResult` in Pass 1. If reconsidered, it requires an explicit memory/size contract.
- On task cancellation, propagate cancellation; do not turn it into an unreadable-article result.

## Fixture corpus

Location: `Tests/TextExtractorWebTests/Fixtures/`.

| Fixture | Intent |
| --- | --- |
| `article-basic.html` | Article title, metadata, three real paragraphs, surrounding site chrome to drop |
| `article-structured.html` | Nested list paragraphs, headings, quote, caption, code, table, and source order |
| `article-entities.html` | Character entities, accented characters, smart quotes, and long prose |
| `non-article-navigation.html` | Site navigation/links without a credible article; reject |
| `non-article-empty.html` | JavaScript-only root and empty body article; reject |

`fixture-cases.json` records **normative expected behavior**: article success/failure, title, and ordered `{ kind, text }` values. These golden expectations are **design targets**, not claims that a parser is implemented or already passing. Pass 2 must test them against actual extraction, document any deliberate semantic adjustments (e.g. whether the article title is an explicit heading or metadata only), and never silently weaken a regression expectation to hide data loss.

Large inputs, malformed encodings (including non-UTF-8 byte sequences), invalid heading values, duplicate IDs, cancellation and deeply nested DOM structures may be **generated in tests** rather than committed as megabyte fixtures.

## Pass 2 implementation: offline semantic extraction

`WebArticleExtractor.extract(html:sourceURL:options:)` is implemented in
`Sources/TextExtractorWeb/WebArticleExtractor.swift`. It operates on supplied
HTML bytes; it does **not** fetch a URL.

- Reader selection: **SwiftReadability 0.3.3**, pinned. The parser runs in the
  calling task, with `ReadabilityOptions.maxElemsToParse` set to the configured
  element limit.
- Structure: **SwiftSoup 2.13.6**, pinned. The selected article fragment is
  walked in DOM source order; block classification is retained during text
  normalization. Headings, paragraphs, list items, blockquotes, code,
  tables and captions are typed, with leftover meaningful unstructured text
  conservatively preserved.
- Deduplication is **structural**, not global string deduplication: paragraph
  descendants of list items and quotes are emitted once as their owning block,
  while identically worded separate occurrences remain intact.
- Normalization collapses whitespace for ordinary prose. Intentional newlines
  in code and tab/newline-separated table text survive.
- IDs use `block-%06d` based on finalized source occurrence order. The
  renderer projects canonical blocks as plain text with `\n\n` separators.
  The title is prepended as a single level-1 heading **only if no level-1
  heading survives** and the extractor supplies a title.
- A webpage without at least `minimumReadableCharacterCount` non-heading
  characters is rejected; there is **no fallback** to dumping site navigation.

Default `WebArticleExtractionOptions` boundaries are:

| Setting | Default |
| --- | ---: |
| `maxInputBytes` | 5 MiB |
| `minimumReadableCharacterCount` | 40 |
| `maxBlocks` | 10,000 |
| `maxDOMDepth` | 128 |
| `maxDOMElements` | 50,000 |

The maximum source size is checked **before** HTML decoding. An element-count
limit is enforced by Readability **after** its initial SwiftSoup parse, so this
is **not** a full CPU/memory isolation sandbox: callers should operate off the
main actor and enforce their own execution-time/cancellation budget for
untrusted inputs.

UTF-8 (with optional BOM) and BOM-marked UTF-16 are recognized; Windows-1252
is a conservative fallback. Embedded NULs are rejected. The original HTML is
not retained in the returned result. Metadata is sourced from Readability;
missing values are not invented.

**Toolchain caveat:** SwiftReadability 0.3.3 requires **Swift 6.2**. Even when
its product is linked only by the optional web target, SwiftPM may still need
to resolve its manifest for ordinary core consumers. Verify existing macOS 15
CI/toolchain compatibility explicitly before releasing; do not change core
source or deployment minimums to hide this compatibility issue.

### Parser acceptance tests

`WebArticleExtractorTests` executes the offline golden fixture manifest,
negative/non-article fixtures, text/typed-block parity, deterministic identity,
metadata, size/URL limitations and cancellation. `WebArticleDOMTests` tests
semantic DOM reconstruction separately from Readability's article selection.

The implementation and tests are committed on the PR. **Apple CI/test execution
remains unverified until the now-manual workflows are dispatched.**

## Pass 1 exit criteria

- [x] Standalone product/target exists; no source under `Sources/TextExtractor/**` changes.
- [x] Typed value models, renderer and validation are implemented in `Sources/TextExtractorWeb/**`.
- [x] Model/serialization tests and a fixture inventory test exist.
- [x] Representative positive/negative article fixtures and expected output specification exist.
- [ ] Run CI/package builds on supported Apple platforms and correct any Pass 1 failures.

Passes 2–5 cover the real parser, demo inspector, mycli-compatible demo release, and final integration/regression checks **inside this package repository only**.
