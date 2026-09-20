import Foundation
import Testing

@testable import KanjiDomain

@Suite("Storico delle esposizioni")
struct AmbientStateTests {
    private let kanji = "06c34"

    private func exposed(_ times: Int, from start: String, every hours: Double = 24) -> (AmbientState, Date) {
        var state = AmbientState.empty
        var moment = date(start)
        for _ in 0..<times {
            state.record(.presented, codepoint: kanji, at: moment)
            moment += hours * .hour
        }
        return (state, moment)
    }

    @Test func theFirstSightingComesBackTheSameDay() throws {
        var state = AmbientState.empty
        state.record(.presented, codepoint: kanji, at: date("2026-05-10 09:00"))

        let exposure = try #require(state.records[kanji])
        #expect(exposure.firstSeenAt == date("2026-05-10 09:00"))
        #expect(exposure.presentationCount == 1)
        #expect(exposure.nextDueAt == date("2026-05-10 15:00"))
        #expect(exposure.stage(at: date("2026-05-10 09:00")) == .fresh)
    }

    @Test func threeSightingsAreNoLongerFresh() {
        let (state, moment) = exposed(3, from: "2026-05-10 09:00", every: 6)
        #expect(state.stage(of: kanji, at: moment) == .reinforcing)
    }

    /// La strada attiva: l'ha aperto e ci è entrato dentro due volte.
    @Test func openingTheReadingsTwiceMakesItFamiliar() {
        var state = AmbientState.empty
        var moment = date("2026-05-10 09:00")
        for _ in 0..<4 {
            state.record(.presented, codepoint: kanji, at: moment)
            moment += 12 * .hour
        }
        state.record(.readingsViewed, codepoint: kanji, at: date("2026-05-10 09:05"))
        state.record(.readingsViewed, codepoint: kanji, at: date("2026-05-11 09:05"))

        #expect(state.stage(of: kanji, at: date("2026-05-12 10:00")) == .familiar)
        // Due giorni non sono ancora passati: contare solo i gesti non basta.
        #expect(state.stage(of: kanji, at: date("2026-05-11 10:00")) == .reinforcing)
    }

    /// La strada passiva, quella che conta per questa app: non l'ha mai aperto,
    /// ma gli è passato davanti per una settimana.
    @Test func eightSightingsInAWeekAreEnoughOnTheirOwn() {
        let (state, _) = exposed(8, from: "2026-05-10 09:00")
        #expect(state.stage(of: kanji, at: date("2026-05-18 09:00")) == .familiar)
        #expect(state.stage(of: kanji, at: date("2026-05-16 09:00")) == .reinforcing)
    }

    @Test func readingsPushTheNextSightingFurtherAway() throws {
        var state = AmbientState.empty
        state.record(.presented, codepoint: kanji, at: date("2026-05-10 09:00"))
        let before = try #require(state.records[kanji]?.nextDueAt)

        state.record(.readingsViewed, codepoint: kanji, at: date("2026-05-10 09:01"))

        let exposure = try #require(state.records[kanji])
        #expect(exposure.nextDueAt > before)
        #expect(exposure.nextDueAt == date("2026-05-11 09:01"))
        #expect(exposure.readingsViewedCount == 1)
        #expect(exposure.lastEngagedAt == date("2026-05-10 09:01"))
    }

    /// Nemmeno arrivare alle letture è una comparsa in più: sposta il ritmo, non il
    /// conteggio di quante volte il kanji ti è passato davanti.
    @Test func readingsDoNotCountAsAnotherSighting() throws {
        var state = AmbientState.empty
        state.record(.presented, codepoint: kanji, at: date("2026-05-10 09:00"))
        state.record(.readingsViewed, codepoint: kanji, at: date("2026-05-10 09:01"))
        state.record(.readingsViewed, codepoint: kanji, at: date("2026-05-10 09:02"))

        let exposure = try #require(state.records[kanji])
        #expect(exposure.presentationCount == 1)
        #expect(exposure.readingsViewedCount == 2)
    }

    /// Aprire è un segnale, non una nuova esposizione: il ritmo non si sposta.
    @Test func openingCountsWithoutChangingTheRhythm() throws {
        var state = AmbientState.empty
        state.record(.presented, codepoint: kanji, at: date("2026-05-10 09:00"))
        state.record(.opened, codepoint: kanji, at: date("2026-05-10 09:02"))

        let exposure = try #require(state.records[kanji])
        #expect(exposure.openedCount == 1)
        #expect(exposure.presentationCount == 1)
        #expect(exposure.nextDueAt == date("2026-05-10 15:00"))
    }

    /// Storico vuoto e app aperta da una notifica vecchia: il kanji è stato mostrato,
    /// anche se questo storico non c'era ancora.
    @Test func openingAKanjiNeverSeenCountsAsASighting() throws {
        var state = AmbientState.empty
        state.record(.opened, codepoint: kanji, at: date("2026-05-10 09:00"))

        let exposure = try #require(state.records[kanji])
        #expect(exposure.presentationCount == 1)
        #expect(exposure.openedCount == 1)
    }

    @Test func survivesASaveAndALoad() throws {
        let (state, _) = exposed(3, from: "2026-05-10 09:00")
        let data = try JSONEncoder().encode(state)
        #expect(try JSONDecoder().decode(AmbientState.self, from: data) == state)
    }
}
