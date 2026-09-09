import Foundation

public struct SRTSubtitleExtractor: TextFormatExtractor {
    public let format: TextExtractionFormat = .srt
    public let supportedFileExtensions: Set<String> = TextExtractionFormat.srt.fileExtensions

    public init() {}

    public func canExtract(data: Data, fileName: String?) -> Bool {
        guard let ext = FileName.fileExtension(from: fileName) else { return false }
        return supportedFileExtensions.contains(ext)
    }

    public func extract(
        data: Data,
        fileName: String?,
        sourceURL: URL?,
        options: TextExtractionOptions
    ) throws -> ExtractedTextDocument {
        let raw = try StringDecoder.decode(data, fileName: fileName)
        let segments = SubtitleParser.parse(raw, format: .srt, options: options)
        let text = SubtitleParser.joinSegments(segments, options: options)

        return ExtractedTextDocument(
            title: FileName.title(from: fileName, sourceURL: sourceURL),
            sourceURL: sourceURL,
            format: format,
            text: text,
            segments: segments
        )
    }
}

public struct VTTSubtitleExtractor: TextFormatExtractor {
    public let format: TextExtractionFormat = .vtt
    public let supportedFileExtensions: Set<String> = TextExtractionFormat.vtt.fileExtensions

    public init() {}

    public func canExtract(data: Data, fileName: String?) -> Bool {
        guard let ext = FileName.fileExtension(from: fileName) else { return false }
        return supportedFileExtensions.contains(ext)
    }

    public func extract(
        data: Data,
        fileName: String?,
        sourceURL: URL?,
        options: TextExtractionOptions
    ) throws -> ExtractedTextDocument {
        let raw = try StringDecoder.decode(data, fileName: fileName)
        let segments = SubtitleParser.parse(raw, format: .vtt, options: options)
        let text = SubtitleParser.joinSegments(segments, options: options)

        return ExtractedTextDocument(
            title: FileName.title(from: fileName, sourceURL: sourceURL),
            sourceURL: sourceURL,
            format: format,
            text: text,
            segments: segments
        )
    }
}

enum SubtitleParser {
    static func parse(_ raw: String, format: TextExtractionFormat, options: TextExtractionOptions) -> [ExtractedTextSegment] {
        let normalized = raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let blocks = normalized
            .components(separatedByRegex: #"\n\s*\n"#)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var segments: [ExtractedTextSegment] = []
        var autoID = 1

        for block in blocks {
            var lines = block.components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            if lines.isEmpty { continue }

            if format == .vtt {
                if lines.first?.uppercased().hasPrefix("WEBVTT") == true { continue }
                if lines.first?.uppercased().hasPrefix("NOTE") == true { continue }
                lines.removeAll { $0.hasPrefix("STYLE") || $0.hasPrefix("REGION") }
            }

            guard let timeLineIndex = lines.firstIndex(where: { $0.contains("-->") }) else { continue }
            let sourceCueID = timeLineIndex > 0 ? lines[timeLineIndex - 1] : nil
            let timeLine = lines[timeLineIndex]
            let textLines = Array(lines.dropFirst(timeLineIndex + 1))

            let text = cleanSubtitleText(textLines.joined(separator: options.subtitleCueSeparator), options: options)
            guard !text.isEmpty else { continue }

            let times = parseTimeLine(timeLine)
            var metadata = ["format": format.rawValue]
            if let sourceCueID, !sourceCueID.isEmpty {
                metadata["sourceCueID"] = sourceCueID
            }
            segments.append(
                ExtractedTextSegment(
                    id: "\(format.rawValue)-\(autoID)",
                    text: text,
                    startTime: times.start,
                    endTime: times.end,
                    metadata: metadata
                )
            )
            autoID += 1
        }

        if options.removeDuplicateSubtitleLines {
            return removeNearDuplicateConsecutiveSegments(segments)
        }

        return segments
    }

    static func joinSegments(_ segments: [ExtractedTextSegment], options: TextExtractionOptions) -> String {
        let joined = segments.map(\.text).joined(separator: options.paragraphSeparator)
        return StringNormalizer.normalize(joined, options: options)
    }

    private static func parseTimeLine(_ line: String) -> (start: TimeInterval?, end: TimeInterval?) {
        let parts = line.components(separatedBy: "-->")
        guard parts.count >= 2 else { return (nil, nil) }

        let startRaw = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let endRaw = parts[1]
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespaces)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return (parseTimestamp(startRaw), parseTimestamp(endRaw))
    }

    private static func parseTimestamp(_ input: String) -> TimeInterval? {
        let value = input.replacingOccurrences(of: ",", with: ".")
        let parts = value.components(separatedBy: ":")
        guard parts.count == 2 || parts.count == 3 else { return nil }

        let secondsPart = parts.last ?? "0"
        guard let seconds = Double(secondsPart) else { return nil }

        if parts.count == 3 {
            guard let hours = Double(parts[0]), let minutes = Double(parts[1]) else { return nil }
            return hours * 3600 + minutes * 60 + seconds
        } else {
            guard let minutes = Double(parts[0]) else { return nil }
            return minutes * 60 + seconds
        }
    }

    private static func cleanSubtitleText(_ input: String, options: TextExtractionOptions) -> String {
        var value = input
        value = value.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
        value = value.replacingOccurrences(of: #"\{[^}]+\}"#, with: "", options: .regularExpression)
        value = HTMLEntityDecoder.decode(value)
        return StringNormalizer.normalize(value, options: options)
    }

    private static func removeNearDuplicateConsecutiveSegments(_ segments: [ExtractedTextSegment]) -> [ExtractedTextSegment] {
        var result: [ExtractedTextSegment] = []
        var previousNormalizedText: String?

        for segment in segments {
            let normalized = segment.text
                .lowercased()
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if normalized != previousNormalizedText {
                result.append(segment)
                previousNormalizedText = normalized
            }
        }

        return result
    }
}

private extension String {
    func components(separatedByRegex regexPattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: regexPattern) else {
            return [self]
        }
        let range = NSRange(startIndex..<endIndex, in: self)
        var results: [String] = []
        var lastLocation = range.location

        for match in regex.matches(in: self, range: range) {
            let partRange = NSRange(location: lastLocation, length: match.range.location - lastLocation)
            if let stringRange = Range(partRange, in: self) {
                results.append(String(self[stringRange]))
            }
            lastLocation = match.range.location + match.range.length
        }

        let tailRange = NSRange(location: lastLocation, length: range.location + range.length - lastLocation)
        if let stringRange = Range(tailRange, in: self) {
            results.append(String(self[stringRange]))
        }
        return results
    }
}
