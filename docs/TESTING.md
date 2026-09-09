# Testing TextExtractor

TextExtractor treats parser behavior as a compatibility surface. Every parser fix should be backed by a focused unit test and, when the issue comes from a real document shape, a regression fixture.

## Supported CI platforms

The package minimums are macOS 15+ and iOS 26+.

GitHub Actions verifies the package and macOS demo on all of these runners:

- Intel macOS 15: `macos-15-intel`
- Apple Silicon macOS 15: `macos-15`
- Apple Silicon macOS 26: `macos-26`

The iOS demo is generated and built for a generic iOS Simulator destination on `macos-26`.

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
  DOCXTextExtractorTests.swift
  DOCXSemanticsTests.swift
  DOCXFailureTests.swift
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

`FixtureSupport` is the shared home for repository fixture discovery, temporary archive creation, archive cleanup, and temp-directory inspection. DOCX/ZIP-based tests should reuse these helpers rather than carrying local ZIPFoundation fixture builders; this keeps entry ordering, cleanup, and ZIP API usage consistent across the suite.

## Fixture corpus

Repository fixtures live under `Fixtures/<extension>/`.

The baseline corpus intentionally contains `short`, `medium`, and `long` samples for each supported extension. `FixtureCorpusTests` automatically discovers these files from the checked-out repository and runs them through the public `TextExtractor` API.

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
