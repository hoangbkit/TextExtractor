import UniformTypeIdentifiers

enum SupportedContentTypes {
    private static let supportedExtensions = [
        "txt", "text",
        "md", "markdown", "mdown", "mkd",
        "srt",
        "vtt", "webvtt",
        "rtf",
        "html", "htm",
        "docx"
    ]

    static let readableTextImports: [UTType] = supportedExtensions.compactMap {
        UTType(filenameExtension: $0)
    }
}
