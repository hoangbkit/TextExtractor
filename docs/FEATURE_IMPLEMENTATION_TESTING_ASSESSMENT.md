# TextExtractor Feature / Implementation / Testing Assessment

This matrix summarizes the current state of `hoangbkit/TextExtractor` reviewed against `master` commit `30ebbe1dab0a7d25a6db7810b89ba222a204ae83`.

Legend:

- ✅ Good / implemented
- 🟡 Partial / moderate
- 🔴 Missing / weak

## Feature matrix

| Feature / area | Implementation | Testing | Assessment |
| --- | --- | --- | --- |
| Core `TextExtractor` API | ✅ Good | 🟡 Moderate | Clean API and extractor abstraction |
| Custom extractors | ✅ Implemented | 🔴 Weak | Supported, but precedence/replacement behavior needs tests |
| TXT extraction | ✅ Good | 🟡 Moderate | Basic UTF/BOM path works |
| UTF-8 decoding | ✅ Good | ✅ Tested | Solid |
| UTF-16 LE/BE | ✅ Implemented | 🔴 Weak | Decoder supports it, tests insufficient |
| Latin-1 fallback | 🟡 Implemented but risky | 🔴 Weak | Can interpret arbitrary binary as text |
| Binary-file rejection | 🔴 Missing | 🔴 Missing | Important hardening gap |
| Whitespace normalization | ✅ Good | 🟡 Moderate | Sensible TTS-oriented behavior |
| Paragraph preservation | ✅ Good | 🟡 Moderate | Custom separator edge cases untested |
| Control-character cleanup | 🟡 Partial | 🔴 Weak | C1/DEL handling should improve |
| Markdown extraction | ✅ Good MVP | 🟡 Moderate | Practical regex-based cleaner |
| YAML front matter | ✅ | ✅ Basic test | Good |
| Markdown headings/lists | ✅ | ✅ Basic | Good common-case support |
| Markdown links | ✅ | ✅ Basic | URL removed, label retained |
| Markdown code blocks | ✅ | ✅ Basic | Fenced code removal works |
| Complex Markdown | 🟡 Partial | 🔴 Weak | Nested links, tables, escapes, etc. |
| SRT parsing | ✅ Good MVP | ✅ Basic | Useful timed segments |
| VTT parsing | ✅ Good MVP | ✅ Basic | Header/settings supported |
| Subtitle timestamps | ✅ | 🟡 Moderate | Malformed timestamps under-tested |
| Subtitle markup cleanup | ✅ | 🟡 Moderate | Regex heuristic |
| Exact duplicate subtitles | ✅ | ✅ Tested | Works |
| Rolling/near-duplicate subtitles | 🔴 Missing | 🔴 Missing | Important for real captions/TTS |
| Unique segment IDs | 🟡 Not guaranteed | 🔴 Missing | Repeated source IDs can collide |
| HTML extraction — Apple | ✅ Good | 🟡 Weak | Uses `NSAttributedString` |
| HTML fallback parser | 🟡 Basic | 🔴 Effectively untested | Existing fallback-named test normally exercises Apple path |
| HTML entity decoding | 🟡 Partial | 🔴 Weak | Numeric good; named entity list is small |
| RTF extraction | ✅ Good on Apple | 🟡 Minimal | Thin `NSAttributedString` wrapper |
| Malformed RTF handling | 🟡 Partial | 🔴 Missing | Needs failure tests |
| DOCX body text | ✅ Good MVP | ✅ Basic | Main WordprocessingML text works |
| DOCX paragraphs | ✅ | ✅ Tested | Good |
| DOCX tabs / line breaks | ✅ | ✅ Basic | Implemented |
| DOCX deleted text | ✅ | 🔴 Weak | Implementation exists; edge cases not exercised |
| DOCX field-code exclusion | ✅ | 🔴 Weak | Same |
| DOCX footnotes | ✅ | ✅ Basic | Appended after body |
| DOCX endnotes | ✅ | ✅ Basic | Appended after body |
| DOCX headers | ✅ Optional | ✅ Basic | Works |
| DOCX footers | ✅ Optional | 🔴 Weak | Same code path but little explicit testing |
| DOCX tables | 🟡 Partial | 🔴 Weak | Text extracted, structure not preserved reliably |
| DOCX reading order | 🟡 Partial | 🔴 Weak | Notes/tables are flattened |
| DOCX numbering/bullets | 🔴 Missing | 🔴 Missing | Labels from numbering definitions are not reconstructed |
| DOCX comments | 🔴 Missing | 🔴 Missing | Current non-goal |
| DOCX tracked changes | 🟡 Partial | 🔴 Weak | Deleted text ignored; richer semantics absent |
| DOCX ZIP validation | 🟡 Weak | 🔴 Missing | Generic ZIP signature may initially be treated as DOCX |
| DOCX decompression limit | 🔴 Missing | 🔴 Missing | Highest-risk issue |
| Input compressed-size limit | ✅ Implemented | 🟡 Weak | 50 MB default |
| Per-entry expanded-size limit | 🔴 Missing | 🔴 Missing | ZIP bomb/resource risk |
| Total expanded-size limit | 🔴 Missing | 🔴 Missing | ZIP bomb/resource risk |
| DOCX temp-file cleanup | 🟡 Bug | 🔴 Missing | File deleted but UUID directory remains |
| XML external entity protection | ✅ Good | 🔴 Weak | Explicitly disabled |
| XML nested ignore-state handling | 🟡 Fragile | 🔴 Missing | Boolean state should probably be depth-based |
| Extension-based detection | ✅ | 🟡 Moderate | Main dispatch mechanism |
| Content sniffing | 🟡 Very limited | 🔴 Weak | Essentially DOCX ZIP signature only |
| Wrong-extension handling | 🟡 Weak | 🔴 Missing | Extension is trusted first |
| Domain errors | ✅ Good API | 🟡 Moderate | Useful cases |
| Error normalization | 🟡 Partial | 🔴 Weak | Foundation/ZIP errors can escape directly |
| Warnings | ✅ Implemented | 🟡 Basic | Human-readable only |
| Machine-readable warnings | 🔴 Missing | 🔴 Missing | Useful future improvement |
| Sendable/concurrency | 🟡 Good with caveat | 🔴 Weak | Uses `@unchecked Sendable`; should be revisited |
| Background extraction | ✅ Supported | 🟡 Demo-level | Synchronous API can be safely dispatched off-main |
| Real fixture corpus | ✅ Exists | 🔴 Poor utilization | Fixtures exist for all supported extensions but most are not driven through tests |
| Inline unit tests | ✅ | 🟡 Moderate | Good happy-path foundation |
| Negative/corrupt-file tests | 🔴 Very sparse | 🔴 Poor | Major gap |
| Boundary/resource tests | 🔴 Sparse | 🔴 Poor | Especially DOCX limits |
| Cross-platform behavior tests | 🔴 Weak | 🔴 Weak | HTML/RTF behavior needs explicit coverage |
| Demo macOS app | ✅ Implemented | — | Useful manual inspection tool |
| Swift Package structure | ✅ Good | 🟡 | Small dependency footprint |
| GitHub Actions CI | 🔴 Missing | 🔴 Missing | Major verification gap |

## Overall assessment

| Dimension | Status |
| --- | --- |
| Architecture | 🟢 Good |
| Public API | 🟢 Good |
| Common TXT/MD/subtitle extraction | 🟢 Good MVP |
| HTML/RTF | 🟢/🟡 Good for normal Apple-app inputs |
| DOCX basic extraction | 🟡 Functional but needs hardening |
| DOCX fidelity | 🟡 Limited |
| Security/resource safety | 🔴 Needs work |
| Unit testing | 🟡 Fair |
| Real-world fixture testing | 🔴 Poor |
| Failure/adversarial testing | 🔴 Poor |
| CI | 🔴 Missing |
| Overall | Good MVP / early-production quality |

## Recommended priority

1. DOCX resource safety: bounded expanded size, per-entry limits, total extraction budget, cleanup.
2. Fixture-driven tests for every supported extension plus GitHub Actions CI.
3. Encoding and binary-input validation.
4. DOCX correctness: tables, ordering, detection, malformed XML/state handling.
5. Subtitle and Markdown edge-case behavior.

For Spokio's normal-user import workflow, the package already has a useful feature set. The largest gap is not feature count; implementation maturity is ahead of verification and hardening.