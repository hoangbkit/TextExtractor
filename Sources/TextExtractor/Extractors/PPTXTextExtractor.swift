import Foundation
import ZIPFoundation

public struct PPTXTextExtractor: TextFormatExtractor {
    private static let presentationPath = "ppt/presentation.xml"
    private static let presentationRelationshipsPath = "ppt/_rels/presentation.xml.rels"
    private static let contentTypesPath = "[Content_Types].xml"

    public let format: TextExtractionFormat = .pptx
    public let supportedFileExtensions: Set<String> = TextExtractionFormat.pptx.fileExtensions

    public init() {}

    public func canExtract(data: Data, fileName: String?) -> Bool {
        if let ext = FileName.fileExtension(from: fileName),
           supportedFileExtensions.contains(ext) {
            return true
        }

        guard data.starts(with: [0x50, 0x4B]) else { return false }

        do {
            let archive = try Archive(data: data, accessMode: .read)
            return archive[Self.contentTypesPath] != nil
                && archive[Self.presentationPath] != nil
                && archive[Self.presentationRelationshipsPath] != nil
        } catch {
            return false
        }
    }

    public func extract(
        data: Data,
        fileName: String?,
        sourceURL: URL?,
        options: TextExtractionOptions
    ) throws -> ExtractedTextDocument {
        let archive = try ArchiveSupport.openArchive(
            data: data,
            sourceURL: sourceURL,
            formatName: "PPTX"
        )
        try ArchiveSupport.validateEntryCount(
            archive,
            options: options,
            formatName: "PPTX"
        )

        guard archive[Self.contentTypesPath] != nil else {
            throw TextExtractionError.invalidDocument(reason: "Missing PPTX [Content_Types].xml.")
        }

        var budget = ArchiveExtractionBudget(options: options, formatName: "PPTX")

        guard let presentationXML = try ArchiveSupport.readEntry(
            Self.presentationPath,
            in: archive,
            budget: &budget
        ) else {
            throw TextExtractionError.invalidDocument(reason: "Missing PPTX presentation.xml.")
        }

        guard let presentationRelationshipsXML = try ArchiveSupport.readEntry(
            Self.presentationRelationshipsPath,
            in: archive,
            budget: &budget
        ) else {
            throw TextExtractionError.invalidDocument(reason: "Missing PPTX presentation relationships.")
        }

        let slideRelationshipIDs: [String]
        let presentationRelationships: [PPTXRelationship]
        do {
            slideRelationshipIDs = try PPTXXMLParser.parseSlideRelationshipIDs(from: presentationXML)
            presentationRelationships = try PPTXXMLParser.parseRelationships(from: presentationRelationshipsXML)
        } catch let error as TextExtractionError {
            throw error
        } catch {
            throw TextExtractionError.invalidDocument(reason: "Could not parse PPTX presentation structure.")
        }

        guard !slideRelationshipIDs.isEmpty else {
            throw TextExtractionError.invalidDocument(reason: "PPTX presentation contains no slides.")
        }

        var relationshipsByID: [String: PPTXRelationship] = [:]
        for relationship in presentationRelationships {
            relationshipsByID[relationship.id] = relationship
        }

        var slideTexts: [String] = []
        var segments: [ExtractedTextSegment] = []

        for (index, relationshipID) in slideRelationshipIDs.enumerated() {
            guard let relationship = relationshipsByID[relationshipID],
                  !relationship.isExternal,
                  relationship.type.lowercased().hasSuffix("/slide"),
                  let slidePath = Self.resolveArchivePath(
                    target: relationship.target,
                    relativeTo: Self.presentationPath
                  ) else {
                throw TextExtractionError.invalidDocument(
                    reason: "Could not resolve PPTX slide relationship: \(relationshipID)."
                )
            }

            guard let slideXML = try ArchiveSupport.readEntry(
                slidePath,
                in: archive,
                budget: &budget
            ) else {
                throw TextExtractionError.invalidDocument(
                    reason: "Missing PPTX slide entry: \(slidePath)."
                )
            }

            let slideBlocks: [PPTXTextBlock]
            do {
                slideBlocks = try PPTXXMLParser.parseTextBlocks(from: slideXML)
            } catch {
                throw TextExtractionError.invalidDocument(
                    reason: "Could not parse PPTX slide \(index + 1)."
                )
            }

            var paragraphs = slideBlocks.compactMap { block -> String? in
                let normalized = normalizeText(block.text, options: options)
                return normalized.isEmpty ? nil : normalized
            }

            var includedSpeakerNotes = false
            if options.includePPTXSpeakerNotes,
               let notesText = try extractSpeakerNotes(
                    forSlidePath: slidePath,
                    archive: archive,
                    budget: &budget,
                    options: options
               ),
               !notesText.isEmpty {
                paragraphs.append(notesText)
                includedSpeakerNotes = true
            }

            let slideText = paragraphs
                .joined(separator: options.preserveParagraphs ? options.paragraphSeparator : " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !slideText.isEmpty else { continue }

            slideTexts.append(slideText)
            segments.append(
                ExtractedTextSegment(
                    id: "slide-\(index + 1)",
                    text: slideText,
                    metadata: [
                        "slideIndex": String(index + 1),
                        "sourcePath": slidePath,
                        "speakerNotesIncluded": includedSpeakerNotes ? "true" : "false"
                    ]
                )
            )
        }

        let text = slideTexts
            .joined(separator: options.preserveParagraphs ? options.paragraphSeparator : " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return ExtractedTextDocument(
            title: FileName.title(from: fileName, sourceURL: sourceURL),
            sourceURL: sourceURL,
            format: format,
            text: text,
            segments: segments,
            metadata: [
                "container": "Office Open XML Presentation",
                "slideCount": String(slideRelationshipIDs.count),
                "expandedArchiveBytes": String(budget.expandedBytes)
            ]
        )
    }

    private func extractSpeakerNotes(
        forSlidePath slidePath: String,
        archive: Archive,
        budget: inout ArchiveExtractionBudget,
        options: TextExtractionOptions
    ) throws -> String? {
        let relationshipsPath = Self.relationshipsPath(for: slidePath)
        guard let relationshipsXML = try ArchiveSupport.readEntry(
            relationshipsPath,
            in: archive,
            budget: &budget
        ) else {
            return nil
        }

        let relationships: [PPTXRelationship]
        do {
            relationships = try PPTXXMLParser.parseRelationships(from: relationshipsXML)
        } catch {
            throw TextExtractionError.invalidDocument(
                reason: "Could not parse PPTX slide relationships: \(relationshipsPath)."
            )
        }

        guard let notesRelationship = relationships.first(where: {
            !$0.isExternal && $0.type.lowercased().hasSuffix("/notesslide")
        }),
        let notesPath = Self.resolveArchivePath(
            target: notesRelationship.target,
            relativeTo: slidePath
        ),
        let notesXML = try ArchiveSupport.readEntry(
            notesPath,
            in: archive,
            budget: &budget
        ) else {
            return nil
        }

        let blocks: [PPTXTextBlock]
        do {
            blocks = try PPTXXMLParser.parseTextBlocks(
                from: notesXML,
                ignoredPlaceholderTypes: ["sldimg", "sldnum", "hdr", "ftr", "dt"]
            )
        } catch {
            throw TextExtractionError.invalidDocument(
                reason: "Could not parse PPTX speaker notes: \(notesPath)."
            )
        }

        let paragraphs = blocks.compactMap { block -> String? in
            let normalized = normalizeText(block.text, options: options)
            return normalized.isEmpty ? nil : normalized
        }

        let text = paragraphs
            .joined(separator: options.preserveParagraphs ? options.paragraphSeparator : " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return text.isEmpty ? nil : text
    }

    private func normalizeText(_ text: String, options: TextExtractionOptions) -> String {
        guard text.contains("\t") else {
            return StringNormalizer.normalize(text, options: options)
        }

        return text
            .components(separatedBy: "\t")
            .map { StringNormalizer.normalize($0, options: options) }
            .joined(separator: "\t")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func relationshipsPath(for partPath: String) -> String {
        let nsPath = partPath as NSString
        let directory = nsPath.deletingLastPathComponent
        let fileName = nsPath.lastPathComponent
        return directory.isEmpty
            ? "_rels/\(fileName).rels"
            : "\(directory)/_rels/\(fileName).rels"
    }

    private static func resolveArchivePath(target: String, relativeTo partPath: String) -> String? {
        let normalizedTarget = target.replacingOccurrences(of: "\\", with: "/")
        var components: [String] = []

        if !normalizedTarget.hasPrefix("/") {
            let directory = (partPath as NSString).deletingLastPathComponent
            components = directory
                .split(separator: "/")
                .map(String.init)
        }

        for component in normalizedTarget.split(separator: "/").map(String.init) {
            switch component {
            case "", ".":
                continue
            case "..":
                guard !components.isEmpty else { return nil }
                components.removeLast()
            default:
                components.append(component)
            }
        }

        guard !components.isEmpty else { return nil }
        return components.joined(separator: "/")
    }
}
