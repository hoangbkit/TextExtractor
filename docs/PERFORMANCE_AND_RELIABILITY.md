# Performance and Reliability

This document defines the Phase 5 reliability and performance policy for TextExtractor. It is deliberately separate from parser semantics: the goal is to detect crashes, hangs, state leaks, resource-limit regressions, and obvious algorithmic slowdowns without making ordinary CI depend on noisy wall-clock thresholds.

## Reliability invariants

For malformed or mutated input, TextExtractor does not promise that extraction succeeds. It promises that handling remains bounded and predictable:

- no crash or trap
- no hang or unbounded loop
- no low-level parser/archive errors escaping where package-domain errors or warnings are expected
- no temporary-directory leakage
- deterministic output for repeated extraction of identical input
- deterministic package errors/warnings for equivalent malformed input
- concurrent reads through a shared `TextExtractor` coordinator remain safe and deterministic
- Phase 1 input/archive limits remain enforced for large and mutated DOCX files

## CI reliability coverage

The normal `swift test --parallel` suite includes deterministic Phase 5 cases for:

- truncating supported text-like formats at multiple offsets
- injecting invalid/control bytes
- duplicating delimiters/byte ranges
- malformed RTF input
- malformed DOCX main XML
- malformed optional DOCX parts
- line-ending and harmless-whitespace variants
- input sizes just below, exactly at, and just over configured limits
- thousands of Markdown paragraphs
- thousands of subtitle cues
- large but permitted DOCX XML
- repeated Markdown and DOCX extraction loops
- temporary-directory stability
- concurrent extraction through one shared coordinator

The mutation corpus is intentionally deterministic rather than random so a failure can be reproduced from a CI log.

## Benchmark harness

Timing benchmarks are implemented in `Phase5BenchmarkTests.swift` but are skipped during ordinary test runs. Run them explicitly with:

```bash
TEXTEXTRACTOR_RUN_BENCHMARKS=1 swift test --filter Phase5BenchmarkTests
```

The harness currently measures representative:

- approximately 1 MB plain text decoding/normalization
- large Markdown cleanup
- 5,000-cue SRT extraction
- large HTML extraction
- large DOCX body extraction

Each benchmark performs a warm-up extraction before measuring repeated iterations and prints milliseconds per iteration, input/output byte counts, and DOCX `expandedArchiveBytes` when available.

## Memory observation

Peak resident memory is environment-dependent and is not asserted in XCTest. On macOS, measure an opt-in benchmark run externally when investigating memory regressions:

```bash
/usr/bin/time -l env TEXTEXTRACTOR_RUN_BENCHMARKS=1 swift test --filter Phase5BenchmarkTests
```

Use the reported maximum resident set size together with DOCX `expandedArchiveBytes` to distinguish package/build overhead from archive expansion.

## Performance expectations

These are regression expectations, not fixed cross-machine pass/fail numbers:

1. Runtime should scale approximately linearly with input size for the supported lightweight text parsers.
2. Repeating the same extraction should not progressively slow down or leave temporary artifacts.
3. Large subtitle processing should scale with cue count rather than previous extraction history.
4. DOCX processing must remain bounded by `maxInputBytes`, `maxArchiveEntryBytes`, `maxExpandedArchiveBytes`, and `maxArchiveEntryCount` regardless of compression ratio.
5. Optional DOCX parts should add work proportional to the selected expanded parts, not the entire ZIP container.
6. A material slowdown should be investigated by comparing the same benchmark case on the same machine/toolchain rather than by comparing absolute numbers across CI runners.

## When to add a regression case

Add a deterministic Phase 5 regression whenever a real document causes:

- crash or hang
- raw dependency/Foundation error leakage
- unexpectedly superlinear behavior
- resource-limit bypass
- repeated-extraction state leakage
- concurrency-only mismatch
- a large performance regression that can be represented by a small generated fixture

Keep performance timing opt-in unless a future regression can be expressed as a stable algorithmic invariant rather than a machine-speed threshold.
