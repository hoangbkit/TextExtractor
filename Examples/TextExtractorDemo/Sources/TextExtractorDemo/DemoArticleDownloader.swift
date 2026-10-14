import Foundation
import TextExtractorWeb

/// Networking belongs to the demo, never to the TextExtractorWeb package.
/// Read HTTP response bytes incrementally so remote pages cannot force an
/// unbounded in-memory download before the parser's size check.
enum DemoArticleDownloader {
    static let maxBytes = 5 * 1024 * 1024

    static func downloadAndExtract(_ address: String) async throws -> WebArticleResult {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.contains("://") ? trimmed : "https://" + trimmed
        guard let url = URL(string: normalized), isAllowed(url) else {
            throw DemoArticleDownloadError.invalidURL
        }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw DemoArticleDownloadError.unsuccessfulResponse(
                (response as? HTTPURLResponse)?.statusCode ?? 0
            )
        }
        // URLSession follows redirects. Validate the final URL too.
        guard let finalURL = http.url, isAllowed(finalURL) else {
            throw DemoArticleDownloadError.invalidURL
        }
        if let mime = http.mimeType?.lowercased(),
           mime != "text/html", mime != "application/xhtml+xml" {
            throw DemoArticleDownloadError.unsupportedContentType(mime)
        }
        if http.expectedContentLength > Int64(maxBytes) {
            throw DemoArticleDownloadError.tooLarge
        }

        var data = Data()
        data.reserveCapacity(64 * 1024)
        for try await byte in bytes {
            data.append(byte)
            if data.count > maxBytes {
                throw DemoArticleDownloadError.tooLarge
            }
            if data.count.isMultiple(of: 4096) {
                try Task.checkCancellation()
            }
        }
        try Task.checkCancellation()
        guard !data.isEmpty else { throw DemoArticleDownloadError.emptyResponse }
        return try WebArticleExtractor().extract(
            html: data,
            sourceURL: finalURL
        )
    }

    private static func isAllowed(_ url: URL) -> Bool {
        // Require HTTPS in the demo; the library itself also accepts HTTP HTML
        // from clients which independently manage their own networking.
        guard url.scheme?.lowercased() == "https",
              let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil else { return false }
        return true
    }
}

enum DemoArticleDownloadError: LocalizedError {
    case invalidURL
    case unsuccessfulResponse(Int)
    case unsupportedContentType(String)
    case tooLarge
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Enter a valid HTTPS article URL."
        case .unsuccessfulResponse(let code):
            return "The article request failed (HTTP \(code))."
        case .unsupportedContentType(let mime):
            return "This URL returned \(mime), not an HTML article."
        case .tooLarge:
            return "The article HTML exceeds the 5 MB demo limit."
        case .emptyResponse:
            return "The article page was empty."
        }
    }
}
