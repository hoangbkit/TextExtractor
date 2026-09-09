# Versioning Policy

TextExtractor follows Semantic Versioning (`MAJOR.MINOR.PATCH`) once tagged releases begin.

## MAJOR

Increment the major version for caller-visible breaking changes, including:

- removing or renaming public types, cases, properties, initializers, or methods
- changing a public type in a source-incompatible way
- removing a supported format or extension
- changing default `TextExtractionOptions` values when the change can materially alter existing caller behavior
- intentionally changing extraction semantics so substantially that existing consumers must adapt
- changing documented error, warning, extractor-dispatch, or segment-identity contracts incompatibly
- raising minimum supported platform versions when that drops previously supported consumers

## MINOR

Increment the minor version for backward-compatible capabilities, including:

- new supported formats or extensions
- new defaulted options
- new warning categories
- additive metadata
- additional parser coverage and semantics that do not invalidate existing API usage
- new diagnostics, benchmarks, or documented capabilities

Parser-quality improvements may ship in a minor release when they materially change otherwise valid output while remaining API-compatible. Call out those changes in `CHANGELOG.md`.

## PATCH

Increment the patch version for compatible fixes, including:

- correcting clearly erroneous parser output
- malformed-input hardening
- crash, hang, leak, and resource-safety fixes
- deterministic behavior fixes
- documentation and CI corrections

A parser fix may change output and still be a patch when the old output was clearly incorrect. Material output changes must still be documented.

## Compatibility rules

Public source compatibility is only one part of the contract. Before releasing, review:

1. public Swift API
2. default option values
3. format/extension support
4. error cases callers may switch over
5. warning codes callers may consume
6. extractor precedence
7. segment identity/metadata behavior
8. documented text semantics
9. supported platform versions

Do not silently repurpose an existing warning code or metadata key to mean something incompatible.

## Dependencies

Dependency upgrades should be reviewed for minimum-platform changes, API behavior, archive/parser behavior, and generated output. A dependency-only update does not automatically qualify as a patch if it materially changes TextExtractor's caller-visible behavior.

## Pre-1.0 releases

If the first tagged versions are `0.x`, use the same discipline even though SemVer technically permits breaking changes in minor releases. For this package, treat breaking changes deliberately and document them as if the package were already stable.
