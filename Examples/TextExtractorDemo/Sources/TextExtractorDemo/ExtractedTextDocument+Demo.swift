import Foundation
import TextExtractor

extension ExtractedTextDocument {
    var demoCharacterCount: Int {
        text.count
    }

    var demoWordCount: Int {
        text.split { $0.isWhitespace || $0.isNewline }.count
    }

    var demoLineCount: Int {
        text.split(separator: "\n", omittingEmptySubsequences: false).count
    }
}

extension TimeInterval {
    var demoTimestamp: String {
        let totalMilliseconds = Int((self * 1000).rounded())
        let milliseconds = totalMilliseconds % 1000
        let totalSeconds = totalMilliseconds / 1000
        let seconds = totalSeconds % 60
        let totalMinutes = totalSeconds / 60
        let minutes = totalMinutes % 60
        let hours = totalMinutes / 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d.%03d", hours, minutes, seconds, milliseconds)
        } else {
            return String(format: "%02d:%02d.%03d", minutes, seconds, milliseconds)
        }
    }
}
