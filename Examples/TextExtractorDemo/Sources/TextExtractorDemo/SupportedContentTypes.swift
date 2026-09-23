import UniformTypeIdentifiers

enum SupportedContentTypes {
    private static var supportedExtensions: [String] {
        var extensions = [
            "txt", "text",
            "md", "markdown", "mdown", "mkd",
            "srt",
            "vtt", "webvtt",
            "rtf",
            "html", "htm",
            "docx", "odt", "pptx"
        ]

        #if os(macOS)
        extensions.append("doc")
        #endif

        return extensions
    }

    static let readableTextImports: [UTType] = supportedExtensions.compactMap {
        UTType(filenameExtension: $0)
    }
}
