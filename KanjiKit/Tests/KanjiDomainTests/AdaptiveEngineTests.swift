import Foundation
import Testing

@testable import KanjiDomain

/// Il ritmo personale: gli stessi kanji, scelti con le stesse regole, ma chi sembra
/// chiedere un appiglio torna un po' prima e con qualcosa in mano.
@Suite("Ritmo personale")
struct AdaptiveEngineTests {
    private let deck = testDeck(count: 30)

    private func hours(_ count: Int, everyMinutes: Int = 60, from start: String = "2026-05-10 08:00") -> [Date] {
        (0..<count).map { date(start) + Double($0 * everyMinutes) * 60 }
    }

    private func plan(_ dates: [Date], state: AmbientState, mode: AmbientMode) -> [AmbientSelection] {
        AmbientEngine.plan(fireDates: dates, deck: deck, state: state, mode: mode, calendar: calendar)
    }

    /// Tre kanji visti nei giorni scorsi, uno dei quali ha chiesto aiuto.
    private func history(asking codepoint: String? = nil, times: Int = 1) -> AmbientState {
        var state = AmbientState.empty
        for index in 0..<3 {
            let moment = date("2026-05-08 09:00") + Double(index) * .hour
            state.record(.presented, codepoint: testCodepoint(index), content: .recall, at: moment)
            state.record(.presented, codepoint: testCodepoint(index), content: .recall, at: moment + 12 * .hour)
        }
        for _ in 0..<times {
            guard let codepoint else { break }
            state.record(.opened, codepoint: codepoint, content: .recall, at: date("2026-05-09 09:00"))
            state.record(.readingsViewed, codepoint: codepoint, content: .recall, at: date("2026-05-09 09:01"))
        }
        return state
    }

    // MARK: - Senza abbonamento non cambia niente

    /// La regola che tiene in piedi tutto il resto: in modalità standard i segnali
    /// esistono ma non si usano, quindi la coda è quella della Fase 2.
    ///
    /// Non confronto due storie diverse fra loro: aprire un kanji sposta comunque il
    /// suo `nextDueAt`, ed è comportamento della Fase 1. Confronto la stessa storia
    /// nei due modi.
    @Test func standardIgnoresTheSignalsItCollects() {
        let dates = hours(20, everyMinutes: 30)
        let asking = history(asking: testCodepoint(1), times: 3)

        let standard = plan(dates, state: asking, mode: .standard)
        let adaptive = plan(dates, state: asking, mode: .adaptive)

        // In standard il kanji che chiede aiuto segue il giro di tutti.
        let askedFor = standard.filter { $0.codepoint == testCodepoint(1) }.map(\.content)
        #expect(askedFor.allSatisfy { ExposureContent.rhythm(for: .low).contains($0) || $0 == .introduce })
        // E i due modi, sulla stessa storia, non danno la stessa coda.
        #expect(standard != adaptive)
    }

    /// E senza segnali, il ritmo personale è il ritmo di tutti: chi guarda e basta
    /// non si accorge di niente.
    @Test func adaptiveWithoutSignalsMatchesStandard() {
        let dates = hours(20, everyMinutes: 30)
        #expect(plan(dates, state: history(), mode: .adaptive) == plan(dates, state: history(), mode: .standard))
    }

    // MARK: - Quando torna

    /// A parità di tutto il resto — stessa ultima comparsa, stessa attesa di base —
    /// chi chiede aiuto torna prima, e chi ne chiede di più prima ancora.
    @Test func askingForHelpBringsItBackSooner() {
        let seen = date("2026-05-10 09:00")
        let now = seen + .hour
        func exposure(_ score: Double) -> KanjiExposure {
            KanjiExposure(
                firstSeenAt: seen - 10 * .day,
                lastPresentedAt: seen,
                presentationCount: 4,
                nextDueAt: seen + 10 * .day,
                supportScore: score,
                supportUpdatedAt: seen
            )
        }
        let quiet = exposure(0)
        let medium = exposure(0.4)
        let high = exposure(0.8)

        #expect(quiet.supportLevel(at: now) == .low)
        #expect(medium.supportLevel(at: now) == .medium)
        #expect(high.supportLevel(at: now) == .high)

        // Standard: la data di base, uguale per tutti e tre.
        for one in [quiet, medium, high] {
            #expect(one.effectiveDueAt(mode: .standard, at: now) == one.nextDueAt)
        }

        // Adaptive: dieci giorni restano dieci giorni per chi non chiede niente,
        // diventano sei e mezzo, e quattro.
        #expect(quiet.effectiveDueAt(mode: .adaptive, at: now) == seen + 10 * .day)
        #expect(medium.effectiveDueAt(mode: .adaptive, at: now) == seen + 6.5 * .day)
        #expect(high.effectiveDueAt(mode: .adaptive, at: now) == seen + 4 * .day)
    }

    /// E lo stesso succede nella coda vera: il kanji che ha chiesto aiuto torna più
    /// spesso di quanto tornerebbe senza.
    @Test func inTheRealQueueItComesBackMoreOften() {
        let asking = testCodepoint(1)
        let dates = hours(20, everyMinutes: 30)
        let state = history(asking: asking, times: 3)

        let standard = plan(dates, state: state, mode: .standard).count { $0.codepoint == asking }
        let adaptive = plan(dates, state: state, mode: .adaptive).count { $0.codepoint == asking }

        #expect(adaptive >= standard)
    }

    /// Mai una raffica: per quanto un kanji sembri costare fatica, non torna prima
    /// di sei ore dall'ultima volta che l'hai visto.
    @Test func neverSoonerThanSixHours() throws {
        var state = AmbientState.empty
        // Un kanji appena visto, e che chiede aiuto quanto può.
        state.record(.presented, codepoint: testCodepoint(0), content: .recall, at: date("2026-05-10 09:00"))
        for _ in 0..<5 {
            state.record(.opened, codepoint: testCodepoint(0), content: .recall, at: date("2026-05-10 09:01"))
        }
        let exposure = try #require(state.records[testCodepoint(0)])

        #expect(exposure.supportLevel(at: date("2026-05-10 09:01")) == .high)
        #expect(exposure.effectiveDueAt(mode: .adaptive, at: date("2026-05-10 09:01")) == date("2026-05-10 15:00"))
    }

    /// Il punteggio decade, e col punteggio torna il ritmo normale: due mesi dopo
    /// quel kanji è un kanji come gli altri.
    @Test func whenTheSignalFadesTheRhythmComesBack() throws {
        let asking = testCodepoint(1)
        let exposure = try #require(history(asking: asking, times: 3).records[asking])

        let soon = date("2026-05-10 08:00")
        let muchLater = date("2026-07-10 08:00")
        #expect(exposure.effectiveDueAt(mode: .adaptive, at: soon) < exposure.nextDueAt)
        #expect(exposure.effectiveDueAt(mode: .adaptive, at: muchLater) == exposure.nextDueAt)
    }

    // MARK: - Come torna

    /// Le prime tre volte sono la grammatica dell'app e non cambiano mai: insegna,
    /// richiama, mostra dentro una parola.
    @Test func theFirstThreeSightingsNeverChange() {
        for support in SupportLevel.allCases {
            #expect(ExposureContent.forSightings(0, support: support, hasWord: true) == .introduce)
            #expect(ExposureContent.forSightings(1, support: support, hasWord: true) == .recall)
            #expect(ExposureContent.forSightings(2, support: support, hasWord: true) == .context)
        }
    }

    /// Dalla quarta in poi, chi chiede aiuto vede più spesso qualcosa a cui
    /// aggrapparsi — ma il richiamo resta nel giro: niente solo risposte pronte.
    @Test func moreSupportMeansMoreToHoldOnTo() {
        let giro = { (support: SupportLevel) in
            (3...6).map { ExposureContent.forSightings($0, support: support, hasWord: true) }
        }

        #expect(giro(.low) == [.recall, .context, .recall, .introduce])
        #expect(giro(.medium) == [.context, .recall, .introduce, .recall])
        #expect(giro(.high) == [.introduce, .context, .recall, .context])
        for support in SupportLevel.allCases {
            #expect(giro(support).contains(.recall), "\(support) senza richiamo")
        }
    }

    @Test func withoutAnExampleWordContextStillFallsBack() {
        #expect(ExposureContent.forSightings(3, support: .medium, hasWord: false) == .introduce)
        #expect(ExposureContent.forSightings(4, support: .high, hasWord: false) == .introduce)
    }

    // MARK: - Le garanzie che valgono comunque

    @Test func theSameHistoryGivesTheSameQueue() {
        let dates = hours(20, everyMinutes: 30)
        let asking = history(asking: testCodepoint(1), times: 3)
        #expect(plan(dates, state: asking, mode: .adaptive) == plan(dates, state: asking, mode: .adaptive))
    }

    @Test func planningLeavesTheHistoryUntouched() {
        let before = history(asking: testCodepoint(1), times: 3)
        _ = plan(hours(20, everyMinutes: 30), state: before, mode: .adaptive)
        #expect(before == history(asking: testCodepoint(1), times: 3))
    }

    @Test func neverTheSameKanjiTwiceInARowEitherWay() {
        let selections = plan(hours(30, everyMinutes: 20), state: history(asking: testCodepoint(1)), mode: .adaptive)
        for (previous, next) in zip(selections, selections.dropFirst()) {
            #expect(previous.codepoint != next.codepoint)
        }
    }
}
