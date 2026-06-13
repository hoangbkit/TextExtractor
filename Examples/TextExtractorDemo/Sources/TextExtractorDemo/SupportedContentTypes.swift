import UniformTypeIdentifiers

extension UTType {
    static let subtitleSRT = UTType(filenameExtension: "srt") ?? .plainText
    static let subtitleVTT = UTType(filenameExtension: "vtt") ?? .plainText
    static let docx = UTType(filenameExtension: "docx") ?? .data
    static let markdownDocument = UTType(filenameExtension: "md") ?? .plainText
    static let markdownLongDocument = UTType(filenameExtension: "markdown") ?? .plainText
}

enum SupportedContentTypes {
    static let readableTextImports: [UTType] = [
        .plainText,
        .text,
        .utf8PlainText,
        .markdownDocument,
        .markdownLongDocument,
        .subtitleSRT,
        .subtitleVTT,
        .rtf,
        .html,
        .docx
    ]
}
