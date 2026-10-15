# TextExtractorWeb — standalone release checklist

Applies to [issue #5](https://github.com/hoangbkit/TextExtractor/issues/5)
and [PR #6](https://github.com/hoangbkit/TextExtractor/pull/6).
This is a **package-only** checklist. It does **not** request any host-app
integration or migration.

## Implementation and scope

- [x] New opt-in `TextExtractorWeb` library target/product; no changes to
      `Sources/TextExtractor/**` or to core `ExtractedTextDocument`.
- [x] Web-only typed `WebArticleBlockKind`, `WebArticleBlock` and
      `WebArticleResult` models, with `WebArticleResult.text` derived
      from canonical ordered blocks.
- [x] HTML in-memory article identification (SwiftReadability), typed
      semantic DOM traversal (SwiftSoup), normalization and deterministic IDs.
- [x] Negative article fixtures, normalization and result-model tests.
- [x] Separate offline article demo UI for both existing macOS/iOS schemes.
- [x] Additive `Package.swift` updates; no generated `.xcodeproj` committed.
- [x] All three CI/release workflows use **manual `workflow_dispatch` only**.
- [x] Demo Release workflow includes a generated Xcode project ZIP for mycli.

## Tests and compatibility — CI executed on preparation branch

- [x] `swift test --parallel` passed in Fast CI #38686086127 and Full CI #38690127546; `swift build -c release` passed in Full CI. These run on preparation commits, not yet a final v1.2.0 tag.
- [ ] Run `swift test --filter WebArticle` and verify all positive and negative
      article fixtures against exact typed ordering, text and metadata.
- [ ] Check repeated extraction determinism, distinct duplicate-text IDs,
      source-order preservation, nested-list de-duplication, unknown text
      preservation, code/table line breaks and exact rendering parity.
- [ ] Check malformed HTML/encoding, oversize input, excessive depth/elements,
      block-count limits and cancellation behavior.
- [x] Existing `TextExtractorTests`, including generic HTML, passed in the full package suite. No changes to the default extractor dispatch, error codes or segmentation.
- [x] **Compiler compatibility assessed:** SwiftReadability 0.3.3 requires Swift 6.2+ for package resolution even for core-only consumers. Swift 6.1.2 failed; Xcode 26.3/Swift 6.2+ passed on both macOS 15 runners. Runtime OS deployment minimums are unchanged. This build-toolchain requirement is documented for the planned v1.2.0 release.
- [ ] Review `TextExtractorWeb` dependency licenses, transitives and
      binary/release distribution obligations.

## Demo and manual CI — automated gates passed

- [x] **Fast CI** passed on the feature branch: [run #38686086127](https://github.com/hoangbkit/TextExtractor/actions/runs/38686086127).
- [x] **Full CI** passed macOS 15 Intel/Apple Silicon, macOS 26 Apple Silicon, and iOS 26 Simulator jobs: [run #38690127546](https://github.com/hoangbkit/TextExtractor/actions/runs/38690127546).
- [x] XcodeGen generated `TextExtractorDemo.xcodeproj` with both shared schemes and the macOS/iOS demo builds passed CI.
- [ ] On macOS and iOS, inspect a normal article (ordered typed blocks,
      text, metadata), structured article (headings, list items, quote,
      caption, table, code), and navigation-only expected error.
- [ ] Confirm generic document fixture navigation, parsed/raw display,
      custom imports and delete operations are unaffected.

## mycli Demo Release — unsigned assets built, local deployment pending

- [x] **Demo Release** successfully ran on the preparation branch: [run #38681709018](https://github.com/hoangbkit/TextExtractor/actions/runs/38681709018).
- [ ] Verify tag `mycli-build-<run-id>-<attempt>` is a GitHub prerelease
      and points to the workflow's checked-out commit SHA.
- [ ] Verify exactly **three** ZIP assets for `both` (two for a
      single-platform run), with no competing Debug+Release assets:

  ```text
  TextExtractorDemo-iOS-unsigned-<tag>.xcarchive.zip
  TextExtractorDemo-macOS-universal-unsigned-<tag>.xcarchive.zip
  TextExtractorDemo-xcodeproj-<tag>.zip
  ```

- [ ] Inspect archives: a single expected app each with the correct
      bundle ID; iOS targets the **device**, not simulator; macOS contains
      `arm64` **and** `x86_64`.
- [ ] Verify `TextExtractorDemo.xcodeproj/project.pbxproj` is at the ZIP
      root path and that relative sources and SwiftPM packages resolve
      after mycli stages the project beside `project.yml`.
- [ ] Verify archive readability, GitHub release asset sizes, and
      that no generated `.xcodeproj` entered Git history.
- [ ] On a local Apple-signing machine with a source checkout:
      `mycli deploy mac --release --tag <tag>` and
      `mycli deploy ios --release --tag <tag>`.
      Confirm that the release project asset bypasses XcodeGen,
      signing succeeds and the apps launch on a suitable destination.
- [ ] Only after the checks above, decide whether the PR can be made
      ready for review and tagged.

## Verification boundary

Automated package tests, macOS/iOS demo builds, and unsigned demo artifacts
passed the linked workflow runs. The interactive demo checks, signed mycli
deployment, physical-device launch, and exact final release-tag validation
remain separate **unchecked** gates. Do not equate a successful unsigned
archive with a successful signed device installation.
