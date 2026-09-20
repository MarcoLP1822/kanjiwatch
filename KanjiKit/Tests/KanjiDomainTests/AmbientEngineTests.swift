import Foundation
import Testing

@testable import KanjiDomain

@Suite("Ambient Engine")
struct AmbientEngineTests {
    private let deck = testDeck(count: 30)

    /// Contatti dalle 8 in poi, tutti dentro la stessa giornata.
    private func hours(_ count: Int, everyMinutes: Int = 60, from start: String = "2026-05-10 08:00") -> [Date] {
        (0..<count).map { date(start) + Double($0 * everyMinutes) * 60 }
    }

    private func plan(
        _ dates: [Date],
        state: AmbientState = .empty,
        deck: KanjiDeck? = nil,
        currentCodepoint: String? = nil,
        newPerDay: Int = AmbientEngine.defaultNewPerDay
    ) -> [AmbientSelection] {
        AmbientEngine.plan(
            fireDates: dates,
            deck: deck ?? self.deck,
            state: state,
            currentCodepoint: currentCodepoint,
            newPerDay: newPerDay,
            calendar: calendar
        )
    }

    /// Uno storico già avviato: cinque kanji visti nei giorni scorsi.
    private func started(_ count: Int = 5) -> AmbientState {
        var state = AmbientState.empty
        for index in 0..<count {
            state.record(
                .presented, codepoint: testCodepoint(index), at: date("2026-05-08 09:00") + Double(index) * .hour)
        }
        return state
    }

    // MARK: - Il ritmo

    @Test func sameStateAndSameDatesGiveTheSameQueue() {
        let dates = hours(20)
        #expect(plan(dates, state: started()) == plan(dates, state: started()))
    }

    /// Cinque rinforzi, tre nuovi, due familiari ogni dieci contatti. Senza familiari
    /// da riproporre quei due slot diventano altri rinforzi, non altri kanji nuovi.
    @Test func tenContactsBringThreeNewKanji() {
        let selections = plan(hours(10), state: started())
        #expect(selections.count == 10)
        #expect(selections.count { $0.kind == .new } == 3)
        #expect(selections.count { $0.kind == .learning } == 7)
    }

    /// Alzare la frequenza aumenta gli incontri, non la roba nuova da imparare.
    @Test func moreContactsDoNotMeanMoreNewKanji() {
        // Stessa finestra di dieci ore, sempre più fitta.
        for (contacts, everyMinutes) in [(10, 60), (20, 30), (30, 20)] {
            let selections = plan(hours(contacts, everyMinutes: everyMinutes), state: started())
            let introduced = selections.count { $0.kind == .new }
            #expect(introduced <= AmbientEngine.defaultNewPerDay, "\(contacts) contatti, \(introduced) nuovi")
        }
    }

    @Test func theDailyBudgetStartsAgainTomorrow() {
        let today = hours(20, everyMinutes: 30)
        let tomorrow = hours(20, everyMinutes: 30, from: "2026-05-11 08:00")
        let selections = plan(today + tomorrow, state: started(), newPerDay: 3)

        for day in ["2026-05-10", "2026-05-11"] {
            let introduced = selections.count {
                $0.kind == .new && calendar.isDate($0.fireDate, inSameDayAs: date("\(day) 12:00"))
            }
            #expect(introduced == 3, "\(day): \(introduced) nuovi")
        }
    }

    /// Un piano fatto a metà giornata non riapre il budget: i nuovi di stamattina
    /// sono già nello storico.
    @Test func aNewPlanAtNoonKeepsThisMorningsBudget() {
        var state = started()
        for index in 10..<13 {
            state.record(.presented, codepoint: testCodepoint(index), at: date("2026-05-10 09:00"))
        }
        let selections = plan(hours(10, from: "2026-05-10 13:00"), state: state, newPerDay: 3)
        #expect(selections.allSatisfy { $0.kind != .new })
    }

    // MARK: - Chi viene scelto

    /// Il primo giorno non c'è niente da rinforzare: si introduce, e nel giro della
    /// stessa giornata quei kanji tornano. Senza aggiungere una sola schermata,
    /// l'app sembra già un'altra cosa.
    @Test func theFirstDayIntroducesAndThenComesBack() {
        let selections = plan(hours(10))

        #expect(selections.first?.kind == .new)
        #expect(selections.first?.codepoint == testCodepoint(0))
        // I nuovi arrivano in ordine di classe e frequenza, non a caso.
        #expect(selections.filter { $0.kind == .new }.map(\.codepoint) == (0..<4).map(testCodepoint))
        // E i primi tornano già oggi.
        #expect(selections.filter { $0.kind == .learning }.contains { $0.codepoint == testCodepoint(0) })
    }

    @Test func newKanjiFollowSchoolGradeBeforeFrequency() {
        // Il kanji 0 è di terza, gli altri di prima: la classe decide per prima.
        let graded = testDeck(count: 5) { $0 == 0 ? 3 : 1 }
        let selections = plan(hours(6), deck: graded)
        #expect(selections.filter { $0.kind == .new }.map(\.codepoint).first == testCodepoint(1))
    }

    /// Vince chi è più in ritardo, e chi sta ancora imparando passa davanti a chi ha
    /// già visto quel kanji decine di volte.
    @Test func theMostOverdueOneWins() throws {
        var state = AmbientState.empty
        // Un kanji familiare per pura esposizione, e in ritardo da una vita.
        for day in 0..<8 {
            state.record(.presented, codepoint: testCodepoint(1), at: date("2026-04-01 09:00") + Double(day) * .day)
        }
        // Uno che sta imparando, in ritardo da ieri.
        state.record(.presented, codepoint: testCodepoint(2), at: date("2026-05-09 09:00"))

        let choice = try #require(
            AmbientEngine.pick(at: date("2026-05-10 08:00"), deck: deck, state: state, calendar: calendar))
        #expect(choice.codepoint == testCodepoint(2))
        #expect(choice.kind == .learning)
    }

    /// Un familiare che non è ancora il suo momento non torna: il suo slot va a un
    /// rinforzo. Senza questa regola, finché ce n'è uno solo si prenderebbe tutti e due
    /// gli slot familiari del ritmo, cioè due comparse al giorno.
    @Test func aFamiliarKanjiWaitsItsTurn() {
        var state = AmbientState.empty
        // Uno solo familiare, appena visto: la sua prossima volta è fra dieci giorni.
        for day in 0..<8 {
            state.record(.presented, codepoint: testCodepoint(1), at: date("2026-05-02 09:00") + Double(day) * .day)
        }
        // E due che sta imparando.
        state.record(.presented, codepoint: testCodepoint(2), at: date("2026-05-09 09:00"))
        state.record(.presented, codepoint: testCodepoint(3), at: date("2026-05-09 10:00"))

        let selections = plan(hours(10), state: state)

        #expect(state.stage(of: testCodepoint(1), at: date("2026-05-10 08:00")) == .familiar)
        #expect(selections.allSatisfy { $0.kind != .familiar })
        #expect(selections.count { $0.codepoint == testCodepoint(1) } == 0)
    }

    @Test func familiarOnesComeBackToo() {
        var state = AmbientState.empty
        // Visti otto giorni di fila e poi spariti da un mese: è il loro momento.
        for index in 1...2 {
            for day in 0..<8 {
                state.record(
                    .presented, codepoint: testCodepoint(index), at: date("2026-04-01 09:00") + Double(day) * .day)
            }
        }
        state.record(.presented, codepoint: testCodepoint(3), at: date("2026-05-09 09:00"))

        let selections = plan(hours(10), state: state)
        #expect(selections.count { $0.kind == .familiar } == 2)
    }

    // MARK: - Le ripetizioni

    @Test func neverTheSameKanjiTwiceInARow() {
        let selections = plan(hours(30, everyMinutes: 20), state: started())
        for (previous, next) in zip(selections, selections.dropFirst()) {
            #expect(previous.codepoint != next.codepoint, "\(label(next.fireDate))")
        }
    }

    /// La prima notifica non ripete il kanji che hai davanti in questo momento.
    @Test func theQueueDoesNotRepeatWhatIsOnScreenNow() {
        let onScreen = testCodepoint(0)
        let selections = plan(hours(3), state: started(), currentCodepoint: onScreen)
        #expect(selections.first?.codepoint != onScreen)
    }

    /// Con un mazzo da un solo kanji non c'è alternativa: meglio ripeterlo che
    /// restare senza niente da mostrare.
    @Test func aSingleKanjiDeckStillFillsTheQueue() {
        let selections = plan(hours(3), deck: testDeck(count: 1))
        #expect(selections.count == 3)
        #expect(Set(selections.map(\.codepoint)) == [testCodepoint(0)])
    }

    // MARK: - Il mazzo

    @Test func onlyTheKanjiOfTheCurrentDeckAreShown() {
        var state = started()
        // Un grado spento nelle impostazioni: la sua storia resta, ma non si mostra.
        state.record(.presented, codepoint: "0ffff", at: date("2026-05-01 09:00"))

        let selections = plan(hours(10), state: state)

        #expect(selections.allSatisfy { deck[$0.codepoint] != nil })
        #expect(state.records["0ffff"] != nil)
    }

    @Test func anEmptyDeckPlansNothing() {
        #expect(plan(hours(5), deck: testDeck(count: 0)).isEmpty)
    }
}
