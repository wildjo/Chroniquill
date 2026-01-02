import Foundation
import Testing
@testable import ChroniQuill

struct MarkdownCodecTests {

    @Test func roundTripMaintainsStructure() async throws {
        let markdown = """
        ---
        title: Sample
        ---

        # Heading One

        - First *item*
        - Second **item** with a [link](https://example.com)

        1. Ordered `code`
        2. Another item
        """

        let document = MarkdownCodec.importDocument(markdown: markdown)
        let exported = MarkdownCodec.exportDocument(document)
        #expect(exported.contains("title: Sample"))
        #expect(exported.contains("# Heading One"))
        #expect(exported.contains("- First *item*"))

        // Round-trip stability
        let roundTripped = MarkdownCodec.exportDocument(MarkdownCodec.importDocument(markdown: exported))
        #expect(roundTripped == exported)
    }

    @Test func sanitizationStripsUnsupportedAttributes() async throws {
        let attributed = NSMutableAttributedString(string: "Styled")
        attributed.addAttribute(.underlineStyle, value: 1, range: NSRange(location: 0, length: attributed.length))
        let sanitized = MarkdownCodec.sanitizePastedContent(AttributedString(attributed))
        #expect(String(sanitized.characters) == "Styled")
    }
}

