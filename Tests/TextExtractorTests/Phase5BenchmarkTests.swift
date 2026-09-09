import Foundation
import XCTest

@testable import TextExtractor

final class Phase5BenchmarkTests: XCTestCase {
    private var benchmarksEnabled: Bool {
        ProcessInfo.processInfo.environment["TEXTEXTRACTOR_RUN_BENCHMARKS"] == "1"
    }

    func testRepresentativeExtractionBenchmarks() throws {
        guard benchmarksEnabled else {
            throw XCTSkip("Set TEXTEXTRACTOR_RUN_BENCHMARKS=1 to run timing benchmarks.")
        }

        let cases: [(name: String, data: Data, fileName: String, iterations: Int)] = [
            ("txt-1mb", Data(String(repeating: "Plain text sentence. ", count: 50_000).utf8), "benchmark.txt", 10),
            ("markdown", Data((0..<5_000).map { "## Heading \($0)\n\nParagraph **bold** [link](https://example.com)." }.joined(separator: "\n\n").utf8), "benchmark.md", 5),
            ("subtitles", Data(makeSRT(cueCount: 5_000).utf8), "benchmark.srt", 5),
            ("html", Data(String(repeating: "<section><h2>Heading</h2><p>Readable <strong>HTML</strong> text.</p></section>", count: 5_000).utf8), "benchmark.html", 5),
            ("docx-body", try makeDOCXData(bodyText: String(repeating: "DOCX benchmark paragraph. ", count: 20_000)), "benchmark.docx", 3)
        ]

        let clock = ContinuousClock()
        for benchmark in cases {
            let extractor = TextExtractor()
            _ = try extractor.extract(data: benchmark.data, fileName: benchmark.fileName)

            let start = clock.now
            var lastDocument: ExtractedTextDocument?
            for _ in 0..<benchmark.iterations {
                lastDocument = try extractor.extract(data: benchmark.data, fileName: benchmark.fileName)
            }
            let elapsed = start.duration(to: clock.now)
            let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1_000_000_000_000_000_000
            let perIterationMilliseconds = seconds * 1_000 / Double(benchmark.iterations)
            let expanded = lastDocument?.metadata["expandedArchiveBytes"] ?? "n/a"

            print(
                "BENCHMARK \(benchmark.name): " +
                String(format: "%.2f ms/iteration", perIterationMilliseconds) +
                ", input=\(benchmark.data.count) bytes, output=\(lastDocument?.text.utf8.count ?? 0) bytes, expandedArchiveBytes=\(expanded)"
            )
        }
    }

    private func makeSRT(cueCount: Int) -> String {
        var value = ""
        for index in 0..<cueCount {
            let start = String(format: "%02d:%02d:%02d,000", index / 3600, (index / 60) % 60, index % 60)
            let endIndex = index + 1
            let end = String(format: "%02d:%02d:%02d,000", endIndex / 3600, (endIndex / 60) % 60, endIndex % 60)
            value += "\(index + 1)\n\(start) --> \(end)\nBenchmark cue \(index)\n\n"
        }
        return value
    }

    private func makeDOCXData(bodyText: String) throws -> Data {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:body><w:p><w:r><w:t>\(bodyText)</w:t></w:r></w:p></w:body>
        </w:document>
        """
        return try FixtureSupport.makeArchiveData(entries: ["word/document.xml": xml])
    }
}
