import Foundation

struct FixtureFile: Identifiable, Hashable {
    let url: URL
    let relativePath: String

    var id: String { relativePath }
    var fileName: String { url.lastPathComponent }
    var folderName: String { url.deletingLastPathComponent().lastPathComponent }
    var fileExtension: String { url.pathExtension.lowercased() }
}

struct FixtureSection: Identifiable {
    let name: String
    let files: [FixtureFile]

    var id: String { name }
}
