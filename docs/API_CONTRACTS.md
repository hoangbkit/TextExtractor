# TextExtractor API Contracts

## Compatibility

The quality/safety roadmap keeps existing call sites source-compatible. Existing public entry points remain available, and new policy knobs use defaults.

## Error boundary

Expected extraction failures are reported as `TextExtractionError` at the public package boundary wherever practical. `invalidDocument(reason:)` is used for malformed containers, unreadable file resources, corrupt archive entries, and parser failures that do not have a more specific existing case.

The existing `TextExtractionError` cases are intentionally retained rather than adding new cases during hardening, because adding enum cases can break downstream exhaustive switches.

## Warnings

`TextExtractionWarning.message` remains available and the existing `TextExtractionWarning("message")` initializer remains valid.

Warnings also carry a stable `TextExtractionWarning.Code`. `.unspecified` preserves compatibility for callers creating message-only warnings.

## Segment identity

`ExtractedTextSegment.id` is unique within a returned subtitle document and is generated deterministically from format plus parsed cue order.

Subtitle source cue IDs are preserved in `segment.metadata["sourceCueID"]` when present. Callers should not treat source cue IDs as unique.

Phase 2 changes identity only; subtitle text-generation and rolling-caption behavior are intentionally left unchanged for the parser-fidelity phase.

## Extractor dispatch

Dispatch is intentionally deterministic:

1. If the filename has an extension supported by one or more configured extractors, the first configured extractor supporting that extension wins.
2. Content sniffing (`canExtract`) is consulted only when no configured extractor matches the extension.
3. When multiple sniffers claim the same data, the first configured extractor wins.
4. Passing `TextExtractor(extractors:)` replaces the default extractor set; it does not augment it.

This behavior is covered by API contract tests.

## Concurrency

`TextExtractor` uses checked `Sendable` conformance. Its extractor list is immutable after initialization, and `TextFormatExtractor` itself requires `Sendable`.

Extraction remains synchronous. Applications should move expensive extraction off the main actor when working with larger files.

## Resource limits

`TextExtractionOptions` includes additive archive safety limits:

- `maxInputBytes`
- `maxArchiveEntryBytes`
- `maxExpandedArchiveBytes`
- `maxArchiveEntryCount`

Archive-backed extractors must enforce declared and actual expansion against these limits.
