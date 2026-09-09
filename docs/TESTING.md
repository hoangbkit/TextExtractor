# Testing TextExtractor

TextExtractor treats parser behavior as a compatibility surface. Every parser fix should be backed by a focused unit test and, when the issue comes from a real document shape, a regression fixture.

## Local verification

Run the complete package suite:

```bash
swift test
```

Verify the release configuration:

```bash
swift build -c release
```

Build the macOS demo without signing:

```bash
make build
```

The same checks run in GitHub Actions for pull requests and pushes to `master`.

## Test organization

Tests are grouped by the component they verify:

```text
Tests/TextExtractorTests/
  CoordinatorTests.swift
  PlainTextExtractorTests.swift
  MarkdownTextExtractorTests.swift
  SubtitleExtractorTests.swift
  HTMLTextExtractorTests.swift
  RTFTextExtractorTests.swift
  DOCXTextExtractorTests.swift
  DOCXFailureTests.swift
  StringDecoderTests.swift
  StringNormalizerTests.swift
  SecurityAndLimitsTests.swift
  FixtureCorpusTests.swift
  FixtureSupport.swift
```

Keep extractor-specific assertions in the corresponding test file. Cross-format coordinator behavior and global limits belong in `CoordinatorTests` or `SecurityAndLimitsTests`.

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
- run `swift test`
- run `swift build -c release`
- ensure the demo still builds
- verify no unrelated fixture output regressed
- prefer safe failure over returning garbage text

Resource-limit, malformed-input, and archive-safety changes should always include boundary and failure tests.
