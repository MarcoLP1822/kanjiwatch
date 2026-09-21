#if os(macOS)
import AppKit
import KanjiDomain
import SwiftUI
import Testing

@testable import StudyFeature

@Suite("Rendering della notifica")
@MainActor
struct GlanceRenderingTests {

    private func render(
        _ content: ExposureContent,
        kanji: Kanji = waterKanji,
        reference: ExposureReference = .none
    ) throws -> NSBitmapImageRep {
        try renderWatchSized(
            ReminderGlanceView(kanji: kanji, viewBox: 109, content: content, reference: reference),
            named: "glance-\(content.rawValue)\(reference == .none ? "" : "-\(reference)")")
    }

    /// La notifica col contesto mostra la parola che il piano ha scelto, non sempre la
    /// più comune: 水着 alle 16, non 水曜日.
    @Test func contextShowsTheWordThatWasChosen() throws {
        let common = inkPixels(try render(.context))
        let second = inkPixels(try render(.context, reference: .word(1)))
        let third = inkPixels(try render(.context, reference: .word(2)))

        #expect(second != common)
        #expect(third != second)
        // Un indice che non c'è più ricade sulla più comune, non su una notifica vuota.
        #expect(inkPixels(try render(.context, reference: .word(9))) == common)
    }

    @Test func showsTheGlyphAndTheMeaning() throws {
        #expect(inkPixels(try render(.introduce)) > 500)
    }

    /// Solo il kanji: la forma del richiamo deve avere meno inchiostro di quella che
    /// scrive anche il significato, altrimenti la riga è rimasta lì.
    @Test func recallShowsTheKanjiAlone() throws {
        #expect(inkPixels(try render(.recall)) < inkPixels(try render(.introduce)))
    }

    /// Nella forma col contesto si disegna la parola, non il kanji: con una parola
    /// diversa l'immagine cambia, e col glifo al suo posto sarebbe identica.
    @Test func contextDrawsTheWordAndNotTheGlyph() throws {
        let sameKanjiOtherWord = Kanji(
            character: waterKanji.character,
            codepoint: waterKanji.codepoint,
            strokes: waterKanji.strokes,
            onReadings: waterKanji.onReadings,
            kunReadings: waterKanji.kunReadings,
            meanings: waterKanji.meanings,
            words: [Kanji.Word(text: "水着", reading: "みずぎ", meanings: ["swimsuit"])]
        )

        #expect(inkPixels(try render(.context)) != inkPixels(try render(.context, kanji: sameKanjiOtherWord)))
        // Tre righe di testo lasciano meno inchiostro di un glifo grande: è il modo
        // più semplice di verificare che il glifo lì non c'è.
        #expect(inkPixels(try render(.context)) < inkPixels(try render(.recall)))
    }

    /// Senza parola d'esempio il contesto non esiste: si ricade sul significato,
    /// non su una schermata vuota.
    @Test func withoutAWordContextLooksLikeAnIntroduce() throws {
        let wordless = Kanji(
            character: waterKanji.character,
            codepoint: waterKanji.codepoint,
            strokes: waterKanji.strokes,
            onReadings: waterKanji.onReadings,
            kunReadings: waterKanji.kunReadings,
            meanings: waterKanji.meanings
        )
        #expect(
            inkPixels(try render(.context, kanji: wordless)) == inkPixels(try render(.introduce, kanji: wordless)))
    }

    /// Il mazzo può cambiare tra quando la notifica viene programmata e quando
    /// arriva: con un kanji che non c'è più, la notifica resta vuota ma non si
    /// rompe.
    @Test func survivesAKanjiThatIsNoLongerInTheDeck() throws {
        let empty = try renderWatchSized(ReminderGlanceView(kanji: nil, viewBox: 109), named: "glance-empty")
        #expect(inkPixels(empty) == 0)
    }
}
#endif
