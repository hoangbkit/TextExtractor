import Foundation
import ZIPFoundation

enum ArchiveSupport {
    static func openArchive(data: Data, sourceURL: URL?, formatName: String) throws -> Archive {
        do {
            if let sourceURL {
                return try Archive(url: sourceURL, accessMode: .read)
            }
            return try Archive(data: data, accessMode: .read)
        } catch {
            throw TextExtractionError.invalidDocument(reason: "Could not open \(formatName) ZIP archive.")
        }
    }

    static func validateEntryCount(
        _ archive: Archive,
        options: TextExtractionOptions,
        formatName: String
    ) throws {
        let maxCount = max(0, options.maxArchiveEntryCount)
        var count = 0
        for _ in archive {
            count += 1
            if count > maxCount {
                throw TextExtractionError.invalidDocument(
                    reason: "\(formatName) archive entry count exceeds maxArchiveEntryCount (\(maxCount))."
                )
            }
        }
    }

    static func readEntry(
        _ path: String,
        in archive: Archive,
        budget: inout ArchiveExtractionBudget
    ) throws -> Data? {
        guard let entry = archive[path] else { return nil }
        guard entry.type == .file else {
            throw TextExtractionError.invalidDocument(
                reason: "\(budget.formatName) archive entry is not a regular file: \(path)."
            )
        }
        return try budget.extract(entry, from: archive)
    }
}

struct ArchiveExtractionBudget {
    let formatName: String
    let maxEntryBytes: UInt64
    let maxExpandedBytes: UInt64
    private(set) var expandedBytes: UInt64 = 0

    init(options: TextExtractionOptions, formatName: String) {
        self.formatName = formatName
        maxEntryBytes = UInt64(max(0, options.maxArchiveEntryBytes))
        maxExpandedBytes = UInt64(max(0, options.maxExpandedArchiveBytes))
    }

    mutating func extract(_ entry: Entry, from archive: Archive) throws -> Data {
        guard entry.uncompressedSize <= maxEntryBytes else {
            throw TextExtractionError.invalidDocument(
                reason: "\(formatName) archive entry exceeds maxArchiveEntryBytes: \(entry.path) expands to \(entry.uncompressedSize) bytes, max \(maxEntryBytes)."
            )
        }
        guard expandedBytes <= maxExpandedBytes,
              entry.uncompressedSize <= maxExpandedBytes - expandedBytes else {
            throw TextExtractionError.invalidDocument(
                reason: "\(formatName) expanded content exceeds maxExpandedArchiveBytes (\(maxExpandedBytes))."
            )
        }

        let remainingExpandedBytes = maxExpandedBytes - expandedBytes
        var actualEntryBytes: UInt64 = 0
        var data = Data()

        do {
            _ = try archive.extract(entry) { chunk in
                let chunkBytes = UInt64(chunk.count)
                guard actualEntryBytes <= UInt64.max - chunkBytes else {
                    throw TextExtractionError.invalidDocument(
                        reason: "\(formatName) archive entry size overflow: \(entry.path)."
                    )
                }

                actualEntryBytes += chunkBytes

                guard actualEntryBytes <= maxEntryBytes else {
                    throw TextExtractionError.invalidDocument(
                        reason: "\(formatName) archive entry exceeds maxArchiveEntryBytes while extracting: \(entry.path)."
                    )
                }
                guard actualEntryBytes <= remainingExpandedBytes else {
                    throw TextExtractionError.invalidDocument(
                        reason: "\(formatName) expanded content exceeds maxExpandedArchiveBytes while extracting."
                    )
                }

                data.append(chunk)
            }
        } catch let error as TextExtractionError {
            throw error
        } catch {
            throw TextExtractionError.invalidDocument(
                reason: "Could not extract \(formatName) archive entry: \(entry.path)."
            )
        }

        expandedBytes += actualEntryBytes
        return data
    }
}
