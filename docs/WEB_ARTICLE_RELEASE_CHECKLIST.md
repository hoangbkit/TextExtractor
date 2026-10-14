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

## Tests and compatibility — NOT EXECUTED

- [ ] Run `swift test --parallel` and `swift build -c release` at the PR head.
- [ ] Run `swift test --filter WebArticle` and verify all positive and negative
      article fixtures against exact typed ordering, text and metadata.
- [ ] Check repeated extraction determinism, distinct duplicate-text IDs,
      source-order preservation, nested-list de-duplication, unknown text
      preservation, code/table line breaks and exact rendering parity.
- [ ] Check malformed HTML/encoding, oversize input, excessive depth/elements,
      block-count limits and cancellation behavior.
- [ ] Verify `TextExtractorTests` (including generic `.html/.htm`) is
      unchanged and every pre-existing test still passes. No changes to
      the default extractor dispatch, error codes or segmentation.
- [ ] **Resolve Swift toolchain compatibility:** SwiftReadability 0.3.3
      uses Swift tools 6.2, while the existing `TextExtractor` package
      specifies 5.9 and previously supported macOS 15 runners. Check
      package-wide SwiftPM resolution on all supported runners, including
      existing core-only consumers. Do not assume target-scoped dependencies
      avoid manifest-resolution requirements.
- [ ] Review `TextExtractorWeb` dependency licenses, transitives and
      binary/release distribution obligations.

## Demo and manual CI — NOT EXECUTED

- [ ] Dispatch **Fast CI** from the intended branch; check package tests.
- [ ] Dispatch **Full CI** from the intended branch; check each macOS
      Intel/Apple Silicon build and the iOS 26 simulator build.
- [ ] Confirm `Examples/TextExtractorDemo/project.yml` generates a single
      `TextExtractorDemo.xcodeproj`, with both shared schemes:
      `TextExtractorDemo-macOS` and `TextExtractorDemo-iOS`.
- [ ] On macOS and iOS, inspect a normal article (ordered typed blocks,
      text, metadata), structured article (headings, list items, quote,
      caption, table, code), and navigation-only expected error.
- [ ] Confirm generic document fixture navigation, parsed/raw display,
      custom imports and delete operations are unaffected.

## mycli Demo Release — NOT EXECUTED

- [ ] Dispatch **Demo Release** manually on the intended commit,
      `platform: both` and `configuration: Release`.
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

## Deferred validation note

The implementation passes were requested **without build, CI, simulator,
real-device, signing or release execution**. Checked implementation items
mean files were committed and the intended contract was written; they do
**not** attest to passing builds or real deployment. Keep every unexecuted
item unchecked until it has been performed.
