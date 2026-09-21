import Foundation
import Testing

@testable import KanjiDomain

/// Lo stesso kanji che, un contesto dopo l'altro, apre pezzi diversi della lingua:
/// 水曜日, poi 水着, poi 水面, e di nuovo 水曜日.
@Suite("Profondità di vocabolario")
struct VocabularyDepthTests {
    private let deck = testDeck(count: 30)

    private func hours(_ count: Int, everyMinutes: Int = 60, from start: String = "2026-05-10 08:00") -> [Date] {
        (0..<count).map { date(start) + Double($0 * everyMinutes) * 60 }
    }

    // MARK: - Quale parola

    /// Le parole girano una per contesto, e dopo l'ultima si ricomincia dalla prima.
    @Test func wordsTakeTurnsOneContextAtATime() {
        let words = testWords(0)
        let turns = (0..<4).map { ExposureReference.next(for: .context, words: words, contextsSoFar: $0) }
        #expect(turns == [.word(0), .word(1), .word(2), .word(0)])
    }

    /// Solo il contesto ha una parola: il significato e il richiamo mostrano il kanji.
    @Test func introduceAndRecallCarryNoWord() {
        let words = testWords(0)
        #expect(ExposureReference.next(for: .introduce, words: words, contextsSoFar: 1) == .none)
        #expect(ExposureReference.next(for: .recall, words: words, contextsSoFar: 1) == .none)
        #expect(ExposureReference.next(for: .context, words: [], contextsSoFar: 1) == .none)
    }

    /// Un indice che non c'è più — il mazzo rigenerato con meno parole dopo che la
    /// notifica era stata programmata — torna alla parola più comune.
    @Test func aStaleIndexFallsBackToTheCommonWord() throws {
        let kanji = try #require(deck.kanji.first)
        #expect(kanji.word(for: .word(1)) == kanji.words[1])
        #expect(kanji.word(for: .word(7)) == kanji.commonWord)
        #expect(kanji.word(for: .none) == kanji.commonWord)
    }

    // MARK: - Nel piano

    /// Dentro un piano solo, ogni contesto dello stesso kanji prende la parola dopo:
    /// la rotazione si legge sulla copia proiettata.
    @Test func thePlanRotatesTheWordsOfEachKanji() {
        let selections = AmbientEngine.plan(
            fireDates: hours(40, everyMinutes: 20), deck: deck, state: .empty, calendar: calendar)

        for codepoint in Set(selections.map(\.codepoint)) {
            let contexts = selections.filter { $0.codepoint == codepoint && $0.content == .context }
            let expected = contexts.indices.map { ExposureReference.word($0 % 3) }
            #expect(contexts.map(\.reference) == expected, "\(codepoint)")
        }
        #expect(selections.filter { $0.content != .context }.allSatisfy { $0.reference == .none })
        #expect(selections.contains { $0.reference == .word(1) })
    }

    /// Il piano riparte da dove era arrivato lo storico vero: chi ha già visto due
    /// contesti di un kanji, al prossimo trova la terza parola.
    @Test func thePlanContinuesFromTheRealHistory() throws {
        var state = AmbientState.empty
        let first = testCodepoint(0)
        // Quattro comparse, due dentro una parola: la quinta, nel giro di tutti, è
        // di nuovo un contesto.
        for (day, content) in [ExposureContent.introduce, .recall, .context, .context].enumerated() {
            state.record(
                .presented, codepoint: first, content: content, at: date("2026-05-05 09:00") + Double(day) * .day)
        }
        #expect(state.records[first]?.contextPresentationCount == 2)

        let next = try #require(
            AmbientEngine.plan(fireDates: hours(10), deck: deck, state: state, calendar: calendar)
                .first { $0.codepoint == first })
        #expect(next.content == .context)
        #expect(next.reference == .word(2))
    }

    @Test func theSameHistoryPicksTheSameWords() {
        let dates = hours(30, everyMinutes: 20)
        let one = AmbientEngine.plan(fireDates: dates, deck: deck, state: .empty, calendar: calendar)
        let two = AmbientEngine.plan(fireDates: dates, deck: deck, state: .empty, calendar: calendar)
        #expect(one.map(\.reference) == two.map(\.reference))
    }

    /// Pianificare non è mostrare: il contatore dei contesti dello storico vero non si
    /// muove per le parole solo previste.
    @Test func planningDoesNotCountContextsThatHaveNotHappened() {
        var state = AmbientState.empty
        state.record(.presented, codepoint: testCodepoint(0), content: .introduce, at: date("2026-05-09 09:00"))
        let before = state

        _ = AmbientEngine.plan(fireDates: hours(30, everyMinutes: 20), deck: deck, state: state, calendar: calendar)

        #expect(state == before)
        #expect(state.records[testCodepoint(0)]?.contextPresentationCount == 0)
    }

    /// Il ritmo personale cambia quando e come torna un kanji, non l'ordine delle sue
    /// parole.
    @Test func theAdaptiveRhythmKeepsTheRotation() {
        var state = AmbientState.empty
        let asking = testCodepoint(1)
        state.record(.presented, codepoint: asking, content: .recall, at: date("2026-05-09 09:00"))
        state.record(.opened, codepoint: asking, content: .recall, at: date("2026-05-09 09:01"))
        state.record(.readingsViewed, codepoint: asking, content: .recall, at: date("2026-05-09 09:02"))

        let selections = AmbientEngine.plan(
            fireDates: hours(40, everyMinutes: 20), deck: deck, state: state, mode: .adaptive, calendar: calendar)
        let contexts = selections.filter { $0.codepoint == asking && $0.content == .context }.map(\.reference)
        #expect(contexts == contexts.indices.map { ExposureReference.word($0 % 3) })
    }

    // MARK: - Nello storico

    /// Il contatore dei contesti si muove solo quando il kanji compare davvero dentro
    /// una parola, e non tocca nient'altro.
    @Test func onlyAContextSightingMovesTheWordCounter() throws {
        var state = AmbientState.empty
        let kanji = testCodepoint(0)
        state.record(.presented, codepoint: kanji, content: .introduce, at: date("2026-05-10 09:00"))
        state.record(.presented, codepoint: kanji, content: .recall, at: date("2026-05-10 15:00"))
        state.record(.opened, codepoint: kanji, content: .context, at: date("2026-05-10 15:01"))
        state.record(.readingsViewed, codepoint: kanji, content: .context, at: date("2026-05-10 15:02"))
        let beforeContext = try #require(state.records[kanji])

        state.record(.presented, codepoint: kanji, content: .context, at: date("2026-05-11 09:00"))
        let after = try #require(state.records[kanji])

        #expect(beforeContext.contextPresentationCount == 0)
        #expect(after.contextPresentationCount == 1)
        // Una comparsa è una comparsa, qualunque parola avesse: il resto va come prima.
        #expect(after.presentationCount == beforeContext.presentationCount + 1)
        #expect(after.supportScore == beforeContext.supportScore)
    }

    /// Storici di prima: si parte dalla prima parola, che è quella che si è sempre vista.
    @Test func aHistorySavedBeforeStartsFromTheFirstWord() throws {
        let saved = """
            {"records":{"06c34":{"firstSeenAt":768484800,"lastPresentedAt":768488400,"presentationCount":3,
            "openedCount":0,"readingsViewedCount":0,"nextDueAt":768574800,"supportScore":0}}}
            """
        let state = try JSONDecoder().decode(AmbientState.self, from: Data(saved.utf8))
        #expect(try #require(state.records["06c34"]).contextPresentationCount == 0)
    }

    // MARK: - Lungo la strada

    @Test func aReminderKeepsItsWordAcrossASave() throws {
        let reminder = ScheduledReminder(
            fireDate: date("2026-05-10 16:00"), codepoint: "06c34", content: .context, reference: .word(1))
        let data = try JSONEncoder().encode(reminder)
        #expect(try JSONDecoder().decode(ScheduledReminder.self, from: data) == reminder)
        #expect(reminder.destination.reference == .word(1))
    }

    @Test func aReminderSavedBeforeHasNoWordChosen() throws {
        let saved = #"{"fireDate":768484800,"codepoint":"06c34","content":"context"}"#
        #expect(try JSONDecoder().decode(ScheduledReminder.self, from: Data(saved.utf8)).reference == .none)
    }

    /// La notifica delle 16 che mostra la seconda parola la porta anche nella sessione:
    /// arrivata, anticipata con NEXT, o aperta dal polso.
    @Test func theWordTravelsIntoTheSession() {
        let reminder = ScheduledReminder(
            fireDate: date("2026-05-10 16:00"), codepoint: "aaaaa", content: .context, reference: .word(1))

        var arrived = ReminderState(scheduled: [reminder])
        arrived.recordDeliveries(now: date("2026-05-10 16:05"), calendar: calendar)
        #expect(arrived.session.reference == .word(1))

        var pulled = ReminderState(
            scheduled: [reminder],
            session: StudySession(codepoint: "old00", isDone: false, since: date("2026-05-10 15:00"))
        )
        _ = pulled.advance(
            after: "old00", now: date("2026-05-10 15:30"), dailyLimit: 10, draw: { nil }, calendar: calendar)
        #expect(pulled.session.reference == .word(1))

        var opened = ReminderState.empty
        opened.open(reminder.destination, now: date("2026-05-10 16:01"))
        #expect(opened.session.reference == .word(1))
    }

    @Test func aSessionSavedBeforeHasNoWordChosen() throws {
        let saved = #"{"scheduled":[],"session":{"codepoint":"04e00","isDone":false,"content":"context"}}"#
        #expect(try JSONDecoder().decode(ReminderState.self, from: Data(saved.utf8)).session.reference == .none)
    }

    /// La notifica si scrive con la parola scelta, e il quadrante mostra la stessa.
    @Test func notificationAndComplicationShowTheSameWord() throws {
        let kanji = try #require(deck.kanji.first)

        let notification = PlannedNotification(
            fireDate: date("2026-05-10 16:00"), kanji: kanji, content: .context, reference: .word(1))
        let glance = GlanceEntry(date: date("2026-05-10 16:00"), kanji: kanji, content: .context, reference: .word(1))

        #expect(notification.word == kanji.words[1])
        #expect(glance.word == kanji.words[1].text)
        #expect(glance.wordReading == kanji.words[1].reading)
        #expect(glance.destination == notification.destination)
    }

    /// E la timeline del quadrante segue la coda: ogni voce con la parola della sua
    /// notifica, quella di adesso con la parola della sessione.
    @Test func theTimelineFollowsTheWordOfEachMoment() throws {
        let kanji = try #require(deck.kanji.first)
        let entries = ComplicationTimeline.entries(
            now: date("2026-05-10 09:00"),
            current: kanji,
            currentContent: .context,
            currentReference: .word(2),
            upcoming: [
                ScheduledReminder(
                    fireDate: date("2026-05-10 10:00"), codepoint: kanji.codepoint, content: .context,
                    reference: .word(1))
            ],
            deck: deck
        )

        #expect(entries.map(\.word) == [kanji.words[2].text, kanji.words[1].text])
    }

    /// Un indice sparito dal mazzo non lascia il quadrante senza parola.
    @Test func aStaleIndexOnTheWristStillShowsAWord() throws {
        let kanji = try #require(deck.kanji.first)
        let glance = GlanceEntry(date: .now, kanji: kanji, content: .context, reference: .word(9))
        #expect(glance.content == .context)
        #expect(glance.word == kanji.commonWord?.text)
    }
}
