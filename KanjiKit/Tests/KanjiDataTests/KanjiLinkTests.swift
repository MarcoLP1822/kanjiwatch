import Foundation
import Testing

@testable import KanjiData

@Suite("Collegamento al kanji")
struct KanjiLinkTests {
    @Test func whatTheComplicationBuildsTheAppReadsBack() {
        let url = KanjiLink.url(for: "06c34")
        #expect(url.absoluteString == "kanjiwatch://kanji/06c34")
        #expect(KanjiLink.codepoint(from: url) == "06c34")
    }

    @Test func ignoresLinksThatAreNotOurs() throws {
        #expect(KanjiLink.codepoint(from: try #require(URL(string: "https://example.com/06c34"))) == nil)
        #expect(KanjiLink.codepoint(from: try #require(URL(string: "kanjiwatch://kanji/"))) == nil)
    }
}
