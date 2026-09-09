import Foundation
import XCTest
import ZIPFoundation

@testable import TextExtractor

final class Phase5MutationTests: XCTestCase {
    func testTextLikeMutationCorpusNeverLeaksUnexpectedErrors() throws {
        let corpus: [(fileName: String, data: Data)] = [
            ("sample.txt", Data("Hello, café 👋\nSecond line".utf8)),
            ("sample.md", Data("# Heading\n\n**bold** [link](https://example.com)\n\n```swift\nprint(1)\n```".utf8)),
            ("sample.html", Data("<html><body><p>Hello &amp; welcome</p><script>ignore()</script></body></html>".utf8)),
            ("sample.srt", Data("1\n00:00:00,000 --> 00:00:01,000\nHello world\n\n2\n00:00:01,000 --> 00:00:02,000\nAgain\n".utf8)),
            ("sample.vtt", Data("WEBVTT\n\n00:00.000 --> 00:01.000\nHello world\n".utf8))
        ]

        for item in corpus {
            for (index, mutation) in deterministicMutations(of: item.data).enumerated() {
                assertSafeExtraction(
                    mutation,
                    fileName: item.fileName,
                    label: "\(item.fileName) mutation \(index)"
                )
            }
        }
    }

    func testMalformedRTFMutationsStayInsidePackageErrorBoundary() throws {
        let source = Data("{\\rtf1\\ansi Hello \\b world\\b0 \\par Second paragraph}".utf8)

        for (index, mutation) in deterministicMutations(of: source).enumerated() {
            do {
                _ = try TextExtractor().extract(data: mutation, fileName: "mutated.rtf")
            } catch let error as TextExtractionError {
                switch error {
                case .invalidDocument, .emptyDocument, .unreadableTextEncoding:
                    break
                default:
                    XCTFail("Unexpected package error for RTF mutation \(index): \(error)")
                }
            } catch {
                XCTFail("RTF mutation \(index) leaked non-package error: \(error)")
            }
        }
    }

    func testDOCXMutationCorpusFailsPredictablyWithoutEscapingSafetyBoundary() throws {
        let validDocument = documentXML(text: "Reliable body text")
        let malformedDocuments = [
            String(validDocument.dropLast()),
            validDocument.replacingOccurrences(of: "</w:p>", with: ""),
            validDocument.replacingOccurrences(of: "<w:t>", with: "<w:t><w:del>"),
            "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body>",
            ""
        ]

        for (index, xml) in malformedDocuments.enumerated() {
            let data = try makeArchiveData(entries: ["word/document.xml": xml])
            do {
                _ = try TextExtractor().extract(data: data, fileName: "mutated-\(index).docx")
            } catch let error as TextExtractionError {
                switch error {
                case .invalidDocument, .emptyDocument:
                    break
                default:
                    XCTFail("Unexpected DOCX package error for mutation \(index): \(error)")
                }
            } catch {
                XCTFail("DOCX mutation \(index) leaked non-package error: \(error)")
            }
        }
    }

    func testDOCXOptionalPartMutationIsWarningOrSuccessNeverRawError() throws {
        let optionalMutations = [
            "<w:footnotes>",
            "<w:footnotes xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:footnote w:id=\"2\"><w:p>",
            ""
        ]

        for (index, footnotes) in optionalMutations.enumerated() {
            let data = try makeArchiveData(entries: [
                "word/document.xml": documentXML(text: "Body remains readable"),
                "word/footnotes.xml": footnotes
            ])

            let document = try TextExtractor().extract(data: data, fileName: "optional-\(index).docx")
            XCTAssertTrue(document.text.contains("Body remains readable"))
            if !footnotes.isEmpty {
                XCTAssertTrue(
                    document.warnings.contains(where: { $0.code == .skippedDOCXFootnotes }),
                    "Malformed optional part should produce a stable warning"
                )
            }
        }
    }

    func testLineEndingAndWhitespaceMutationsRemainDeterministic() throws {
        let variants = [
            "First line\nSecond line\n\nThird line",
            "First line\r\nSecond line\r\n\r\nThird line",
            "First line\rSecond line\r\rThird line",
            "First   line\nSecond\tline\n\n\nThird line"
        ]

        let outputs = try variants.map {
            try TextExtractor().extract(data: Data($0.utf8), fileName: "lines.txt").text
        }

        XCTAssertEqual(Set(outputs).count, 1)
        XCTAssertEqual(outputs[0], "First line\nSecond line\n\nThird line")
    }

    private func deterministicMutations(of data: Data) -> [Data] {
        var mutations: [Data] = []
        mutations.append(Data())
        mutations.append(Data(data.prefix(max(0, data.count / 4))))
        mutations.append(Data(data.prefix(max(0, data.count / 2))))
        if !data.isEmpty {
            mutations.append(Data(data.dropLast()))
        }

        var inserted = data
        let midpoint = inserted.count / 2
        inserted.insert(contentsOf: [0x00, 0xFF, 0x1B], at: midpoint)
        mutations.append(inserted)

        var duplicated = data
        if data.count >= 4 {
            let range = (data.count / 3)..<min(data.count, data.count / 3 + 4)
            duplicated.insert(contentsOf: data[range], at: range.upperBound)
        }
        mutations.append(duplicated)

        return mutations
    }

    private func assertSafeExtraction(_ data: Data, fileName: String, label: String) {
        do {
            _ = try TextExtractor().extract(data: data, fileName: fileName)
        } catch is TextExtractionError {
            // A deterministic package-domain failure is an acceptable mutation outcome.
        } catch {
            XCTFail("\(label) leaked non-package error: \(error)")
        }
    }

    private func makeArchiveData(entries: [String: String]) throws -> Data {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TextExtractorPhase5Mutation-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = directory.appendingPathComponent("fixture.docx")
        let archive = try Archive(url: url, accessMode: .create)

        for path in entries.keys.sorted() {
            let entryData = Data((entries[path] ?? "").utf8)
            try archive.addEntry(
                with: path,
                type: .file,
                uncompressedSize: Int64(entryData.count),
                compressionMethod: .deflate
            ) { position, size in
                let start = Int(position)
                return entryData.subdata(in: start..<(start + size))
            }
        }
        return try Data(contentsOf: url)
    }

    private func documentXML(text: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:body><w:p><w:r><w:t>\(text)</w:t></w:r></w:p></w:body>
        </w:document>
        """
    }
}
