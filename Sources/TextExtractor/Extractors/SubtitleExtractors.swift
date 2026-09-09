import Foundation

public struct SRTSubtitleExtractor: TextFormatExtractor {
    public let format: TextExtractionFormat = .srt
    public let supportedFileExtensions: Set<String> = TextExtractionFormat.srt.fileExtensions
    public init() {}
    public func canExtract(data: Data, fileName: String?) -> Bool {
        guard let ext = FileName.fileExtension(from: fileName) else { return false }
        return supportedFileExtensions.contains(ext)
    }
    public func extract(data: Data, fileName: String?, sourceURL: URL?, options: TextExtractionOptions) throws -> ExtractedTextDocument {
        let raw = try StringDecoder.decode(data, fileName: fileName)
        let result = SubtitleParser.parse(raw, format: .srt, options: options)
        return ExtractedTextDocument(title: FileName.title(from: fileName, sourceURL: sourceURL), sourceURL: sourceURL,
            format: format, text: SubtitleParser.joinSegments(result.segments, options: options), segments: result.segments, warnings: result.warnings)
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
    public func extract(data: Data, fileName: String?, sourceURL: URL?, options: TextExtractionOptions) throws -> ExtractedTextDocument {
        let raw = try StringDecoder.decode(data, fileName: fileName)
        let result = SubtitleParser.parse(raw, format: .vtt, options: options)
        return ExtractedTextDocument(title: FileName.title(from: fileName, sourceURL: sourceURL), sourceURL: sourceURL,
            format: format, text: SubtitleParser.joinSegments(result.segments, options: options), segments: result.segments, warnings: result.warnings)
    }
}

enum SubtitleParser {
    struct ParseResult { var segments: [ExtractedTextSegment]; var warnings: [TextExtractionWarning] }

    static func parse(_ raw: String, format: TextExtractionFormat, options: TextExtractionOptions) -> ParseResult {
        let normalized = raw.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let blocks = normalized.components(separatedByRegex: #"\n\s*\n"#)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        var segments: [ExtractedTextSegment] = []
        var warnings: [TextExtractionWarning] = []
        var autoID = 1

        for block in blocks {
            let lines = block.components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            if lines.isEmpty { continue }
            if format == .vtt {
                let first = lines.first?.uppercased() ?? ""
                if first.hasPrefix("WEBVTT") || first.hasPrefix("NOTE") || first.hasPrefix("STYLE") || first.hasPrefix("REGION") { continue }
            }
            guard let timeLineIndex = lines.firstIndex(where: { $0.contains("-->") }) else { continue }
            let sourceCueID = timeLineIndex > 0 ? lines[timeLineIndex - 1] : nil
            let timeLine = lines[timeLineIndex]
            let text = cleanSubtitleText(Array(lines.dropFirst(timeLineIndex + 1)).joined(separator: options.subtitleCueSeparator), options: options)
            guard !text.isEmpty else { continue }
            let times = parseTimeLine(timeLine)
            if times.start == nil || times.end == nil {
                warnings.append(TextExtractionWarning(code: .malformedSubtitleTimestamp,
                    message: "Could not parse subtitle timestamp for cue \(sourceCueID ?? String(autoID))."))
            }
            var metadata = ["format": format.rawValue]
            if let sourceCueID, !sourceCueID.isEmpty { metadata["sourceCueID"] = sourceCueID }
            segments.append(ExtractedTextSegment(id: "\(format.rawValue)-\(autoID)", text: text,
                startTime: times.start, endTime: times.end, metadata: metadata))
            autoID += 1
        }
        if options.removeDuplicateSubtitleLines { segments = removeRollingDuplicateContent(segments) }
        return ParseResult(segments: segments, warnings: warnings)
    }

    static func joinSegments(_ segments: [ExtractedTextSegment], options: TextExtractionOptions) -> String {
        StringNormalizer.normalize(segments.map(\.text).joined(separator: options.paragraphSeparator), options: options)
    }

    private static func parseTimeLine(_ line: String) -> (start: TimeInterval?, end: TimeInterval?) {
        let parts = line.components(separatedBy: "-->")
        guard parts.count >= 2 else { return (nil, nil) }
        let startRaw = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let endRaw = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespaces).first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return (parseTimestamp(startRaw), parseTimestamp(endRaw))
    }

    private static func parseTimestamp(_ input: String) -> TimeInterval? {
        let parts = input.replacingOccurrences(of: ",", with: ".").components(separatedBy: ":")
        guard parts.count == 2 || parts.count == 3, let seconds = Double(parts.last ?? ""), seconds >= 0, seconds < 60 else { return nil }
        if parts.count == 3 {
            guard let hours = Double(parts[0]), let minutes = Double(parts[1]), hours >= 0, minutes >= 0, minutes < 60 else { return nil }
            return hours * 3600 + minutes * 60 + seconds
        }
        guard let minutes = Double(parts[0]), minutes >= 0 else { return nil }
        return minutes * 60 + seconds
    }

    private static func cleanSubtitleText(_ input: String, options: TextExtractionOptions) -> String {
        var value = input
        value = value.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
        value = value.replacingOccurrences(of: #"\{[^}]+\}"#, with: "", options: .regularExpression)
        value = HTMLEntityDecoder.decode(value)
        return StringNormalizer.normalize(value, options: options)
    }

    private static func removeRollingDuplicateContent(_ segments: [ExtractedTextSegment]) -> [ExtractedTextSegment] {
        var result: [ExtractedTextSegment] = []
        var previousNormalizedWords: [String] = []
        for segment in segments {
            let originalWords = segment.text.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            let normalizedWords = originalWords.map { $0.lowercased() }
            guard !normalizedWords.isEmpty else { continue }
            if normalizedWords == previousNormalizedWords { previousNormalizedWords = normalizedWords; continue }
            var overlap = 0
            let maximum = min(previousNormalizedWords.count, normalizedWords.count)
            if maximum > 0 {
                for size in stride(from: maximum, through: 1, by: -1) {
                    if Array(previousNormalizedWords.suffix(size)) == Array(normalizedWords.prefix(size)) { overlap = size; break }
                }
            }
            var emitted = segment
            if overlap > 0 && overlap < originalWords.count {
                emitted.text = originalWords.dropFirst(overlap).joined(separator: " ")
            } else if overlap == originalWords.count {
                previousNormalizedWords = normalizedWords
                continue
            }
            result.append(emitted)
            previousNormalizedWords = normalizedWords
        }
        return result
    }
}

private extension String {
    func components(separatedByRegex regexPattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: regexPattern) else { return [self] }
        let range = NSRange(startIndex..<endIndex, in: self)
        var results: [String] = []; var lastLocation = range.location
        for match in regex.matches(in: self, range: range) {
            let partRange = NSRange(location: lastLocation, length: match.range.location - lastLocation)
            if let stringRange = Range(partRange, in: self) { results.append(String(self[stringRange])) }
            lastLocation = match.range.location + match.range.length
        }
        let tailRange = NSRange(location: lastLocation, length: range.location + range.length - lastLocation)
        if let stringRange = Range(tailRange, in: self) { results.append(String(self[stringRange])) }
        return results
    }
}
