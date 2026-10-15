# Testing TextExtractor

TextExtractor treats parser behavior as a compatibility surface. Every parser fix should be backed by a focused unit test and, when the issue comes from a real document shape, a regression fixture.

## Supported CI platforms

The package minimums are macOS 15+ and iOS 26+.

When **Full CI is manually dispatched**, its matrix runs the package and macOS demo on these runners:

- Intel macOS 15: `macos-15-intel`
- Apple Silicon macOS 15: `macos-15`
- Apple Silicon macOS 26: `macos-26`

The iOS demo is generated and built for a generic iOS Simulator destination on `macos-26`. **Fast CI**, **Full CI** and **Demo Release** are all `workflow_dispatch`-only. There are no automatic push/PR CI events. The web-feature package tests passed [Fast CI #38686086127](https://github.com/hoangbkit/TextExtractor/actions/runs/38686086127); the macOS/iOS demo build matrix passed [Full CI #38690127546](https://github.com/hoangbkit/TextExtractor/actions/runs/38690127546).

## Local verification

Run the complete package suite:

```bash
swift test --parallel
```

Verify the release configuration:

```bash
swift build -c release
```

Both demo apps use XcodeGen. Install it first:

```bash
brew install xcodegen
```

Generate/build the macOS demo:

```bash
make build
```

Generate/build the iOS simulator demo:

```bash
make ios-build
```

Generated `.xcodeproj` directories are intentionally ignored and must not be committed.

### Web-article development commands

For the optional article product and test target, the relevant commands are:

```bash
swift test --filter WebArticle
swift build --product TextExtractorWeb
```

`WebArticleModelTests` covers the standalone immutable model and serialization
contract. `WebArticleDOMTests` exercises semantic traversal and structural
de-duplication independently of Readability's article selection.
`WebArticleExtractorTests` exercises HTML-to-typed-result extraction, golden
fixture parity, deterministic IDs, metadata, rejection cases, cancellation and
limits. Golden data lives under `Tests/TextExtractorWebTests/Fixtures` and is
intended to lock down output semantics, not merely check nonempty text.

**Toolchain:** The new SwiftReadability 0.3.3 dependency requires **Swift
6.2+ for the entire package graph**, even when clients link only core
`TextExtractor`. Swift 6.1.2 failed dependency resolution on macOS 15;
Full CI succeeded when Xcode 26.3 was selected. This is a compiler/toolchain
requirement; deployment minimums remain macOS 15.0 and iOS 26.0.

### Manual Actions and demo-release verification

Run **Fast CI** for package tests, then **Full CI** for the macOS/iOS demo
build matrix. For the separately provisioned **Demo Release** workflow, select
platform `both` and configuration `Release` (or one platform if deliberately
testing only one). A successful dispatch should publish:

```text
TextExtractorDemo-iOS-unsigned-mycli-build-<run-id>-<attempt>.xcarchive.zip
TextExtractorDemo-macOS-universal-unsigned-mycli-build-<run-id>-<attempt>.xcarchive.zip
TextExtractorDemo-xcodeproj-mycli-build-<run-id>-<attempt>.zip
```

The iOS archive must be a device `iphoneos` archive, not a Simulator build.
The macOS archive must contain both `arm64` and `x86_64`. The Xcode project
ZIP must contain exactly one top-level `TextExtractorDemo.xcodeproj/` project,
including its `project.pbxproj`; no generated project is committed.
Release metadata must point to the checkout SHA, and each selected platform
must have exactly one matching deployable asset.

The actual release deployment remains a **separate manual gate** on a signed
local machine using `mycli deploy mac --release --tag <tag>` and
`mycli deploy ios --release --tag <tag>`. See the
[web-article release checklist](WEB_ARTICLE_RELEASE_CHECKLIST.md) for exact
remaining manual requirements. [Demo Release #38681709018](https://github.com/hoangbkit/TextExtractor/actions/runs/38681709018) passed for unsigned assets and the generated project ZIP; signed local deployment and the final semantic-version release have **not** been validated.


## Test organization

Tests are grouped by the behavior they verify:

```text
Tests/TextExtractorTests/
  APIContractTests.swift
  CoordinatorTests.swift
  PlainTextExtractorTests.swift
  MarkdownTextExtractorTests.swift
  SubtitleExtractorTests.swift
  HTMLTextExtractorTests.swift
  RTFTextExtractorTests.swift
  DOCTextExtractorTests.swift
  DOCXTextExtractorTests.swift
  DOCXSemanticsTests.swift
  DOCXFailureTests.swift
  ODTTextExtractorTests.swift
  PPTXTextExtractorTests.swift
  StringDecoderTests.swift
  StringNormalizerTests.swift
  SecurityAndLimitsTests.swift
  Phase1SafetyTests.swift
  Phase5MutationTests.swift
  Phase5ReliabilityTests.swift
  Phase5BenchmarkTests.swift
  FixtureCorpusTests.swift
  FixtureSupport.swift
```

Keep extractor-specific assertions in the corresponding test file. Cross-format coordinator behavior and global limits belong in `CoordinatorTests`, `APIContractTests`, or `SecurityAndLimitsTests` as appropriate.

`FixtureSupport` is the shared home for repository fixture discovery, temporary archive creation, archive cleanup, and temp-directory inspection. DOCX/ODT/PPTX/ZIP-based tests should reuse these helpers rather than carrying local ZIPFoundation fixture builders; this keeps entry ordering, cleanup, and ZIP API usage consistent across the suite.

## Fixture corpus

Repository fixtures live under `Fixtures/<extension>/`.

The baseline corpus contains `short`, `medium`, and `long` samples for text-like/container formats with checked-in fixtures. Legacy `.doc` is macOS-only and uses focused native round-trip tests that generate actual Microsoft Word format data through Apple's AppKit attributed-string exporter. `FixtureCorpusTests` automatically discovers these files from the checked-out repository and runs them through the public `TextExtractor` API.

Current fixture directories:

- `Fixtures/txt`
- `Fixtures/md`
- `Fixtures/markdown`
- `Fixtures/srt`
- `Fixtures/vtt`
- `Fixtures/rtf`
- `Fixtures/html`
- `Fixtures/htm`
- `Fixtures/docx`
- `Fixtures/odt`
- `Fixtures/pptx`

## Adding a regression fixture

When fixing a parser bug caused by a real document shape:

1. Reduce the input to the smallest file that still reproduces the issue when practical.
2. Remove private or identifying content before committing it.
3. Put the file in the matching `Fixtures/<extension>/` directory, or create a clearly named subdirectory for specialized regression cases once the baseline corpus grows.
4. Add a focused XCTest that states the behavior being protected. Do not rely only on the generic corpus smoke test.
5. Assert semantic output, not incidental implementation details.
6. For deterministic parser paths, exact output assertions are preferred. For platform-dependent Apple importers, assert representative text and absence of markup instead of full-string equality.
7. Include a failure-path or malformed-input fixture when the bug involves unsafe or invalid input.

## Fixture assertion policy

The generic corpus test verifies that:

- every checked-in baseline fixture is consumed
- extraction succeeds
- output is non-empty
- the detected format is correct
- representative short-fixture text survives extraction
- obvious source/container markup does not leak into output

Format-specific tests should go deeper and assert exact semantics where the output is deterministic.

## TextExtractorWeb fixture invariants

When web-article parsing changes, compare its typed `blocks` before comparing
rendered `text`. Assert ordered kind, content, distinct occurrence IDs, and
exact `blocks.map(\\.text).joined(separator: "\\n\\n") == result.text`
for each positive fixture. Do not convert unstructured plain text into fake
typed paragraphs merely to satisfy a fixture. Distinguish absent/empty metadata
from guessed values, and assert non-article/boilerplate pages reject safely.

For core regression protection, run the existing `TextExtractorTests` corpus
unchanged and compare the original generic HTML path against its pre-feature
expectations. The web feature must not modify `Sources/TextExtractor/**` or
`ExtractedTextDocument` or alter default extraction dispatch.

## Parser change checklist

Before merging a parser behavior change:

- add or update focused tests
- add a regression fixture when useful
- reuse shared `FixtureSupport` utilities instead of duplicating fixture infrastructure
- run `swift test --parallel`
- run `swift build -c release`
- regenerate both XcodeGen demo projects
- build the macOS demo
- build the iOS demo for the Simulator
- verify no unrelated fixture output regressed
- prefer safe failure over returning garbage text

Resource-limit, malformed-input, and archive-safety changes should always include boundary and failure tests.
