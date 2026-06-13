import Foundation

enum FileName {
    static func title(from fileName: String?, sourceURL: URL?) -> String {
        if let sourceURL {
            return sourceURL.deletingPathExtension().lastPathComponent
        }

        guard let fileName, !fileName.isEmpty else {
            return "Untitled"
        }

        return URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
    }

    static func fileExtension(from fileName: String?) -> String? {
        guard let fileName else { return nil }
        let ext = URL(fileURLWithPath: fileName).pathExtension.lowercased()
        return ext.isEmpty ? nil : ext
    }
}
