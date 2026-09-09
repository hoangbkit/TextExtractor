# Release and Spokio Sync Checklist

Use this checklist for every tagged TextExtractor release and every standalone-to-Spokio synchronization.

## 1. Standalone package gate

- [ ] PR scope matches the intended release.
- [ ] `swift test --parallel` passes on Intel macOS 15, Apple Silicon macOS 15, and Apple Silicon macOS 26 CI runners.
- [ ] `swift build -c release` passes on the same three macOS runners.
- [ ] macOS demo is regenerated from XcodeGen and builds with code signing disabled on all three macOS runners.
- [ ] iOS demo is regenerated from XcodeGen and builds for an iOS Simulator on the Apple Silicon macOS 26 runner.
- [ ] No generated `.xcodeproj` directory is committed.
- [ ] Fixture corpus is green for every supported format.
- [ ] Mutation, boundary, repeat-extraction, and concurrency tests are green.
- [ ] Any relevant opt-in performance benchmark has been sampled for material parser changes.
- [ ] CI contains no new actionable warnings.

## 2. Compatibility review

- [ ] Review public API changes against `docs/API_CONTRACTS.md`.
- [ ] Review default `TextExtractionOptions` values.
- [ ] Confirm package minimums remain macOS 15+ and iOS 26+ unless an intentional SemVer-impacting change is documented.
- [ ] Review supported formats/extensions.
- [ ] Review new/changed `TextExtractionError` behavior.
- [ ] Review new/changed `TextExtractionWarning.Code` values.
- [ ] Review extractor precedence and custom-extractor behavior.
- [ ] Review segment identity and metadata contracts.
- [ ] Review output-affecting parser changes against documented format semantics.
- [ ] Decide the SemVer impact using `docs/VERSIONING.md`.

## 3. Release notes and tag

- [ ] Move relevant `CHANGELOG.md` entries from `Unreleased` under the release version/date.
- [ ] Explicitly call out changed defaults, resource limits, platform minimums, new formats, and material output changes.
- [ ] Confirm the release commit SHA.
- [ ] Create the version tag only after CI is green on that exact commit.

## 4. Sync into Spokio

Spokio consumes a synchronized copy of TextExtractor, so treat package sync as a separate verification step rather than assuming standalone CI is sufficient.

- [ ] Choose the exact TextExtractor tag/revision to sync.
- [ ] Run Spokio's package sync workflow/script from the intended Spokio target branch.
- [ ] Verify the TextExtractor revision recorded in `Packages/REVISION_LOCK.json` matches the chosen standalone revision.
- [ ] Confirm the synchronized TextExtractor source tree matches that revision with no silent local drift.
- [ ] Review the Spokio diff before committing the sync.

## 5. Spokio integration verification

- [ ] Build the affected Spokio target(s).
- [ ] Run Spokio document-import/unit tests.
- [ ] Exercise representative TXT and Markdown imports.
- [ ] Exercise representative SRT/VTT imports, including rolling captions.
- [ ] Exercise HTML and RTF imports.
- [ ] Exercise representative DOCX files containing paragraphs, tables, lists, notes, and optional headers/footers where relevant.
- [ ] Confirm warnings/errors surface appropriately in the host app.
- [ ] Confirm large/malformed files fail safely without blocking the UI or leaking temporary artifacts.

## 6. Final release gate

- [ ] Standalone TextExtractor CI green on the release SHA across the full macOS/iOS demo matrix.
- [ ] Spokio CI/build/tests green on the synchronized revision.
- [ ] Representative manual imports look correct.
- [ ] Changelog and release notes match shipped behavior.
- [ ] No unreviewed parser/default/resource-limit/platform changes remain.

If any package behavior changes after Spokio verification, restart the relevant standalone and integration gates rather than reusing earlier results.
