//
//  MarkdownCodec.swift
//  ChroniQuill
//
//  A lightweight codec that translates Markdown into an editable rich text
//  representation (AttributedString with explicit structural attributes) and
//  back. The focus is on stability and deterministic output rather than full
//  Markdown fidelity. Unsupported attributes are stripped while preserving the
//  underlying text so the editor never crashes on unexpected input.
//
//  Created by ChatGPT.
//

import Foundation

// MARK: - Attribute definitions

/// Block-level intent for an attributed range. We avoid inferring meaning from
/// typography by attaching explicit semantic markers that survive edits.
enum RichBlockKind: Codable, Hashable {
    case paragraph
    case heading(Int)
    case unorderedListItem
    case orderedListItem(Int)
}

struct MarkdownBlockAttribute: CodableAttributedStringKey {
    static var name: String = "chroniquill.block"
    typealias Value = RichBlockKind
}

extension AttributeScopes {
    struct ChroniquillAttributes: AttributeScope {
        let markdownBlock: MarkdownBlockAttribute
    }

    var chroniquill: ChroniquillAttributes.Type { ChroniquillAttributes.self }
}

// MARK: - Document container

struct MarkdownDocument {
    var frontMatter: String?
    var body: AttributedString
}

// MARK: - Codec

enum MarkdownCodec {
    /// Parse a Markdown string into a document with an attributed body. The
    /// attributed body carries explicit structural attributes so the UI can edit
    /// it without losing intent.
    static func importDocument(markdown: String) -> MarkdownDocument {
        let (frontMatter, remainder) = extractFrontMatter(from: markdown)
        let blocks = parseBlocks(from: remainder)
        let attributed = makeAttributedString(from: blocks)
        return MarkdownDocument(frontMatter: frontMatter, body: sanitizeForEditing(attributed))
    }

    /// Export an attributed document back into deterministic Markdown.
    static func exportDocument(_ document: MarkdownDocument) -> String {
        let sanitized = sanitizeForEditing(document.body)
        let markdownBody = blocks(from: sanitized).map { block in
            switch block.kind {
            case .heading(let level):
                return String(repeating: "#", count: max(1, min(level, 6))) + " " + encodeInline(block.text)
            case .unorderedListItem:
                return "- " + encodeInline(block.text)
            case .orderedListItem(let ordinal):
                return "\(max(1, ordinal)). " + encodeInline(block.text)
            case .paragraph:
                return encodeInline(block.text)
            }
        }.joined(separator: "\n\n")

        if let fm = document.frontMatter?.trimmingCharacters(in: .whitespacesAndNewlines), !fm.isEmpty {
            return fm + "\n\n" + markdownBody
        } else {
            return markdownBody
        }
    }

    /// Remove unsupported attributes while keeping text content intact. This is
    /// used for paste handling and as a defensive step before export.
    static func sanitizeForEditing(_ attributed: AttributedString) -> AttributedString {
        var sanitized = AttributedString()
        for run in attributed.runs {
            var container = AttributeContainer()

            // Preserve our explicit block kind if present
            if let block = run.attributes[MarkdownBlockAttribute.self] {
                container[MarkdownBlockAttribute.self] = block
            }

            // Preserve supported inline intents
            if let intent = run.inlinePresentationIntent {
                container.inlinePresentationIntent = intent.intersection([.emphasized, .stronglyEmphasized, .code])
            }

            if let link = run.link {
                container.link = link
            }

            let substring = attributed[run.range]
            sanitized.append(AttributedString(String(substring.characters), attributes: container))
        }
        return sanitized
    }

    /// Transform pasted rich text into the supported model. Currently this
    /// simply routes to `sanitizeForEditing` but is kept separate for clarity.
    static func sanitizePastedContent(_ attributed: AttributedString) -> AttributedString {
        sanitizeForEditing(attributed)
    }

    // MARK: - Internal parsing helpers

    private struct ParsedBlock {
        var kind: RichBlockKind
        var text: AttributedString
    }

    private static func extractFrontMatter(from markdown: String) -> (String?, String) {
        var lines = markdown.components(separatedBy: "\n")
        guard lines.first == "---" else { return (nil, markdown) }

        var frontMatterLines: [String] = []
        lines.removeFirst()
        while let line = lines.first {
            lines.removeFirst()
            if line == "---" { break }
            frontMatterLines.append(line)
        }

        let frontMatter = (["---"] + frontMatterLines + ["---"]).joined(separator: "\n")
        return (frontMatter, lines.joined(separator: "\n"))
    }

    private static func parseBlocks(from markdown: String) -> [ParsedBlock] {
        var blocks: [ParsedBlock] = []
        let paragraphs = markdown.replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n\n")
        for paragraph in paragraphs {
            let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            if let headingMatch = headingRegex.firstMatch(in: trimmed, options: [], range: NSRange(location: 0, length: (trimmed as NSString).length)),
               let range = Range(headingMatch.range(at: 1), in: trimmed) {
                let level = trimmed[range].count
                let textRange = Range(headingMatch.range(at: 2), in: trimmed) ?? trimmed.startIndex..<trimmed.endIndex
                let content = String(trimmed[textRange])
                blocks.append(ParsedBlock(kind: .heading(level), text: makeInlineAttributedString(from: content)))
                continue
            }

            if let unorderedMatch = unorderedListRegex.firstMatch(in: trimmed, options: [], range: NSRange(location: 0, length: (trimmed as NSString).length)),
               let textRange = Range(unorderedMatch.range(at: 1), in: trimmed) {
                let content = String(trimmed[textRange])
                blocks.append(ParsedBlock(kind: .unorderedListItem, text: makeInlineAttributedString(from: content)))
                continue
            }

            if let orderedMatch = orderedListRegex.firstMatch(in: trimmed, options: [], range: NSRange(location: 0, length: (trimmed as NSString).length)),
               let numberRange = Range(orderedMatch.range(at: 1), in: trimmed),
               let textRange = Range(orderedMatch.range(at: 2), in: trimmed) {
                let ordinal = Int(trimmed[numberRange]) ?? 1
                let content = String(trimmed[textRange])
                blocks.append(ParsedBlock(kind: .orderedListItem(ordinal), text: makeInlineAttributedString(from: content)))
                continue
            }

            blocks.append(ParsedBlock(kind: .paragraph, text: makeInlineAttributedString(from: trimmed)))
        }
        return blocks
    }

    private static func makeAttributedString(from blocks: [ParsedBlock]) -> AttributedString {
        var attributed = AttributedString()
        for (index, block) in blocks.enumerated() {
            var container = AttributeContainer()
            container[MarkdownBlockAttribute.self] = block.kind
            var blockString = AttributedString()

            for run in block.text.runs {
                var mergedAttributes = container
                mergedAttributes.merge(run.attributes)
                let segment = AttributedString(String(block.text[run.range].characters), attributes: mergedAttributes)
                blockString.append(segment)
            }

            attributed.append(blockString)
            if index != blocks.count - 1 {
                attributed.append(AttributedString("\n\n"))
            }
        }
        return attributed
    }

    private static func makeInlineAttributedString(from text: String) -> AttributedString {
        var attributed = AttributedString()
        var remainder = text
        while !remainder.isEmpty {
            if let linkMatch = firstLinkMatch(in: remainder) {
                let before = remainder.prefix(upTo: linkMatch.range.lowerBound)
                if !before.isEmpty {
                    attributed.append(AttributedString(String(before)))
                }
                let label = String(remainder[linkMatch.labelRange])
                if let url = URL(string: String(remainder[linkMatch.urlRange])) {
                    var container = AttributeContainer()
                    container.link = url
                    attributed.append(AttributedString(label, attributes: container))
                } else {
                    attributed.append(AttributedString(label))
                }
                remainder = String(remainder[linkMatch.range.upperBound...])
                continue
            }

            if let boldMatch = firstContentMatch(for: boldRegex, in: remainder) {
                let before = remainder.prefix(upTo: boldMatch.range.lowerBound)
                if !before.isEmpty { attributed.append(AttributedString(String(before))) }
                let content = String(remainder[boldMatch.contentRange])
                var container = AttributeContainer()
                container.inlinePresentationIntent = .stronglyEmphasized
                attributed.append(AttributedString(content, attributes: container))
                remainder = String(remainder[boldMatch.range.upperBound...])
                continue
            }

            if let italicMatch = firstContentMatch(for: italicRegex, in: remainder) {
                let before = remainder.prefix(upTo: italicMatch.range.lowerBound)
                if !before.isEmpty { attributed.append(AttributedString(String(before))) }
                let content = String(remainder[italicMatch.contentRange])
                var container = AttributeContainer()
                container.inlinePresentationIntent = .emphasized
                attributed.append(AttributedString(content, attributes: container))
                remainder = String(remainder[italicMatch.range.upperBound...])
                continue
            }

            if let codeMatch = firstContentMatch(for: codeRegex, in: remainder) {
                let before = remainder.prefix(upTo: codeMatch.range.lowerBound)
                if !before.isEmpty { attributed.append(AttributedString(String(before))) }
                let content = String(remainder[codeMatch.contentRange])
                var container = AttributeContainer()
                container.inlinePresentationIntent = .code
                attributed.append(AttributedString(content, attributes: container))
                remainder = String(remainder[codeMatch.range.upperBound...])
                continue
            }

            attributed.append(AttributedString(remainder))
            remainder.removeAll()
        }
        return attributed
    }

    private static func encodeInline(_ text: AttributedString) -> String {
        var result = ""
        for run in text.runs {
            let substring = text[run.range]
            let content = String(substring.characters)
            var wrapped = content

            if let link = run.link {
                wrapped = "[\(wrapped)](\(link.absoluteString))"
            }

            if let intent = run.inlinePresentationIntent {
                if intent.contains(.code) {
                    wrapped = "`\(wrapped)`"
                }
                if intent.contains(.stronglyEmphasized) {
                    wrapped = "**\(wrapped)**"
                }
                if intent.contains(.emphasized) {
                    wrapped = "*\(wrapped)*"
                }
            }

            result.append(wrapped)
        }
        return result
    }

    private static func blocks(from attributed: AttributedString) -> [ParsedBlock] {
        var collected: [ParsedBlock] = []
        var current = AttributedString()
        var currentKind: RichBlockKind = .paragraph
        var pendingNewlines = 0

        for run in attributed.runs {
            if let block = run.attributes[MarkdownBlockAttribute.self] {
                currentKind = block
            }

            let substring = attributed[run.range]
            for character in substring.characters {
                if character == "\n" {
                    pendingNewlines += 1
                    continue
                }

                if pendingNewlines >= 2 {
                    collected.append(ParsedBlock(kind: currentKind, text: current))
                    current = AttributedString()
                    currentKind = .paragraph
                    pendingNewlines = 0
                } else if pendingNewlines == 1 {
                    current.append(AttributedString("\n"))
                    pendingNewlines = 0
                }

                current.append(AttributedString(String(character), attributes: run.attributes))
            }
        }

        if pendingNewlines >= 2 && !current.isEmpty {
            collected.append(ParsedBlock(kind: currentKind, text: current))
            current = AttributedString()
        } else if pendingNewlines == 1 {
            current.append(AttributedString("\n"))
        }

        if !current.isEmpty {
            collected.append(ParsedBlock(kind: currentKind, text: current))
        }

        return collected
    }

    // MARK: - Regular expressions

    private static let headingRegex = try! NSRegularExpression(pattern: "^(#{1,6})\\s+(.*)$", options: [.anchorsMatchLines])
    private static let unorderedListRegex = try! NSRegularExpression(pattern: "^[\\-*+]\\s+(.*)$", options: [])
    private static let orderedListRegex = try! NSRegularExpression(pattern: "^(\\d+)[.)]\\s+(.*)$", options: [])
    private static let boldRegex = try! NSRegularExpression(pattern: "\\*\\*(.+?)\\*\\*", options: [])
    private static let italicRegex = try! NSRegularExpression(pattern: "\\*(.+?)\\*", options: [])
    private static let codeRegex = try! NSRegularExpression(pattern: "`([^`]+)`", options: [])
    private static let linkRegex = try! NSRegularExpression(pattern: "\\[([^\\]]+)\\]\\(([^\\)]+)\\)", options: [])

    private struct RegexMatch {
        let range: Range<String.Index>
        let contentRange: Range<String.Index>
        let labelRange: Range<String.Index>
        let urlRange: Range<String.Index>
    }

    private static func firstContentMatch(for regex: NSRegularExpression, in text: String) -> (range: Range<String.Index>, contentRange: Range<String.Index>)? {
        let nsRange = NSRange(location: 0, length: (text as NSString).length)
        guard let match = regex.firstMatch(in: text, options: [], range: nsRange), match.numberOfRanges >= 2,
              let mainRange = Range(match.range(at: 0), in: text),
              let contentRange = Range(match.range(at: 1), in: text) else { return nil }
        return (mainRange, contentRange)
    }

    private static func firstLinkMatch(in text: String) -> RegexMatch? {
        let nsRange = NSRange(location: 0, length: (text as NSString).length)
        guard let match = linkRegex.firstMatch(in: text, options: [], range: nsRange),
              let range = Range(match.range(at: 0), in: text),
              match.numberOfRanges >= 3,
              let label = Range(match.range(at: 1), in: text),
              let url = Range(match.range(at: 2), in: text) else { return nil }
        return RegexMatch(range: range, contentRange: label, labelRange: label, urlRange: url)
    }
}

