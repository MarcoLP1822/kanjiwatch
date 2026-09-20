import Foundation
import Testing

@testable import KanjiDomain

@Suite("Loop di studio")
struct StudyLoopTests {
    private func reminder(_ time: String, _ codepoint: String) -> ScheduledReminder {
        ScheduledReminder(fireDate: date(time), codepoint: codepoint)
    }

    private func studying(_ codepoint: String, since time: String) -> StudySession {
        StudySession(codepoint: codepoint, isDone: false, since: date(time))
    }

    private func state(
        scheduled: [ScheduledReminder],
        session: StudySession = .none,
        today: DailyCount = .none
    ) -> ReminderState {
        ReminderState(scheduled: scheduled, session: session, today: today)
    }

    // MARK: - Regole

    /// NEXT non inventa un kanji in più: anticipa quello della prossima notifica.
    @Test func nextPullsTheUpcomingNotificationForward() {
        var value = state(
            scheduled: [reminder("2026-05-10 11:00", "bbbbb"), reminder("2026-05-10 10:00", "aaaaa")],
            session: studying("old00", since: "2026-05-10 09:00")
        )
        let now = date("2026-05-10 09:12").addingTimeInterval(37)

        let outcome = value.advance(
            after: "old00", now: now, dailyLimit: 10, draw: { ReminderDestination(codepoint: "zzzzz") },
            calendar: calendar)

        #expect(outcome == .showing("aaaaa"))
        #expect(value.scheduled == [reminder("2026-05-10 11:00", "bbbbb")])
        #expect(value.session == StudySession(codepoint: "aaaaa", isDone: false, since: now))
        #expect(value.today.count(on: now, calendar: calendar) == 1)
        // L'intervallo riparte dal minuto, come i trigger delle notifiche.
        #expect(value.anchor == date("2026-05-10 09:12"))
    }

    @Test func withoutQueuedNotificationsNextDrawsFromTheDeck() {
        var value = state(scheduled: [])
        let outcome = value.advance(
            after: nil, now: date("2026-05-10 09:12"), dailyLimit: 10,
            draw: { ReminderDestination(codepoint: "zzzzz") }, calendar: calendar)
        #expect(outcome == .showing("zzzzz"))
    }

    /// I kanji fatti con NEXT contano: raggiunto il numero, per oggi è finita.
    @Test func nextStopsAtTheDailyLimit() {
        let now = date("2026-05-10 09:12")
        var value = state(
            scheduled: [reminder("2026-05-10 10:00", "aaaaa")],
            session: studying("old00", since: "2026-05-10 09:00"),
            today: DailyCount(day: calendar.startOfDay(for: now), count: 3)
        )

        #expect(
            value.advance(
                after: "old00", now: now, dailyLimit: 3, draw: { ReminderDestination(codepoint: "zzzzz") },
                calendar: calendar)
                == .dailyLimitReached)
        #expect(value.scheduled.count == 1)
    }

    /// Una notifica arrivata mentre studiavi è il prossimo kanji: NEXT la mostra
    /// senza anticiparne un'altra e senza contarla due volte.
    @Test func nextShowsANotificationThatArrivedWhileStudying() {
        let now = date("2026-05-10 10:05")
        var value = state(
            scheduled: [reminder("2026-05-10 10:00", "arrvd"), reminder("2026-05-10 11:00", "later")],
            session: studying("old00", since: "2026-05-10 09:55")
        )

        #expect(
            value.advance(
                after: "old00", now: now, dailyLimit: 10, draw: { ReminderDestination(codepoint: "zzzzz") },
                calendar: calendar)
                == .showing("arrvd"))
        #expect(value.scheduled == [reminder("2026-05-10 11:00", "later")])
        #expect(value.today.count(on: now, calendar: calendar) == 1)
        #expect(value.anchor == nil)
    }

    /// DONE vale per il kanji che hai davanti, non per quello arrivato nel frattempo.
    @Test func doneDoesNotCloseAKanjiYouHaveNotSeen() {
        var value = state(
            scheduled: [reminder("2026-05-10 10:00", "arrvd")],
            session: studying("old00", since: "2026-05-10 09:55")
        )
        value.recordDeliveries(now: date("2026-05-10 10:05"), calendar: calendar)

        value.markDone("old00")

        #expect(value.session.codepoint == "arrvd")
        #expect(!value.session.isDone)
    }

    @Test func doneKeepsTheKanjiButClosesItsTurn() {
        var value = state(scheduled: [], session: studying("aaaaa", since: "2026-05-10 09:00"))
        value.markDone("aaaaa")
        #expect(value.session.codepoint == "aaaaa")
        #expect(value.session.isDone)
    }

    /// Le notifiche arrivate contano nella giornata, e l'ultima diventa il kanji in gioco.
    @Test func deliveredNotificationsCountAndTakeOver() {
        let now = date("2026-05-10 09:12")
        var value = state(
            scheduled: [
                reminder("2026-05-10 08:00", "aaaaa"), reminder("2026-05-10 09:00", "bbbbb"),
                reminder("2026-05-10 10:00", "ccccc"),
            ],
            session: StudySession(codepoint: "old00", isDone: true, since: date("2026-05-10 07:00"))
        )

        value.recordDeliveries(now: now, calendar: calendar)

        #expect(value.today.count(on: now, calendar: calendar) == 2)
        #expect(value.session == studying("bbbbb", since: "2026-05-10 09:00"))
        #expect(value.scheduled == [reminder("2026-05-10 10:00", "ccccc")])
    }

    /// Un NEXT premuto dopo l'ultima notifica non va scavalcato da quella notifica.
    @Test func anOlderNotificationDoesNotReplaceANewerKanji() {
        let nextPressed = studying("next0", since: "2026-05-10 09:05")
        var value = state(scheduled: [reminder("2026-05-10 09:00", "aaaaa")], session: nextPressed)

        value.recordDeliveries(now: date("2026-05-10 09:12"), calendar: calendar)

        #expect(value.session == nextPressed)
    }

    @Test func yesterdaysNotificationsDoNotCountToday() {
        let now = date("2026-05-10 09:12")
        var value = state(scheduled: [reminder("2026-05-09 21:00", "aaaaa")])

        value.recordDeliveries(now: now, calendar: calendar)

        #expect(value.today.count(on: now, calendar: calendar) == 0)
    }

    /// Stato salvato quando esisteva ancora il giro del mazzo: il campo sparito si
    /// ignora, e la coda e il kanji in gioco si leggono lo stesso.
    @Test func stateSavedWithTheOldDeckCycleStillLoads() throws {
        let saved = #"""
            {"cycle":{"order":["aaaaa","bbbbb"],"position":1},
             "scheduled":[{"fireDate":768484800,"codepoint":"04e00"}]}
            """#
        let value = try JSONDecoder().decode(ReminderState.self, from: Data(saved.utf8))
        #expect(value.scheduled.map(\.codepoint) == ["04e00"])
        #expect(value.session == .none)
        #expect(value.anchor == nil)
    }

    // MARK: - Con le porte

    private let deck = KanjiDeck(
        viewBox: 109,
        attribution: "",
        kanji: ["一", "二", "三"].map { character in
            Kanji(
                character: character,
                codepoint: String(format: "%05x", character.unicodeScalars.first!.value),
                strokes: ["M0,0"],
                onReadings: [],
                kunReadings: [],
                meanings: ["number"]
            )
        }
    )

    private func loop(
        state: InMemoryStore<ReminderState>,
        ambient: InMemoryStore<AmbientState> = InMemoryStore(.empty),
        dailyLimit: Int = 10,
        at time: String
    ) -> StudyLoop {
        var settings = ReminderSettings.default
        settings.dailyLimit = dailyLimit
        return StudyLoop(
            deck: deck,
            settings: InMemoryStore(settings),
            state: state,
            ambient: ambient,
            now: { date(time) },
            calendar: calendar
        )
    }

    /// Al primo avvio c'è subito un kanji, e conta nella giornata come un NEXT.
    @Test func theFirstLaunchPutsAKanjiInPlay() throws {
        let store = InMemoryStore(ReminderState.empty)

        let snapshot = try #require(loop(state: store, at: "2026-05-10 09:12").current())

        #expect(deck[snapshot.current.codepoint] != nil)
        #expect(!snapshot.isDone)
        #expect(snapshot.nextArrival == nil)
        #expect(store.value.today.count(on: date("2026-05-10 09:12"), calendar: calendar) == 1)
        // Rileggere non è un gesto: il kanji resta quello.
        #expect(loop(state: store, at: "2026-05-10 09:13").current()?.current == snapshot.current)
    }

    @Test func doneThenNextUntilTheDayIsOver() throws {
        let store = InMemoryStore(ReminderState.empty)
        let first = try #require(loop(state: store, dailyLimit: 2, at: "2026-05-10 09:12").current())

        let done = try #require(loop(state: store, dailyLimit: 2, at: "2026-05-10 09:13").done(first.current.codepoint))
        #expect(done.isDone)
        #expect(!done.dailyLimitReached)

        let second = try #require(
            loop(state: store, dailyLimit: 2, at: "2026-05-10 09:14").next(after: first.current.codepoint))
        #expect(second.current != first.current)
        #expect(second.dailyLimitReached)

        let refused = try #require(
            loop(state: store, dailyLimit: 2, at: "2026-05-10 09:15").next(after: second.current.codepoint))
        #expect(refused == second)
    }

    // MARK: - I segnali che finiscono nello storico

    /// Una notifica arrivata è un'esposizione, all'ora in cui è arrivata. Una ancora
    /// in coda no: il piano l'ha prevista, e prevederla non è averla vista.
    @Test func onlyNotificationsThatArrivedCount() throws {
        let store = InMemoryStore(
            ReminderState(
                scheduled: [
                    ScheduledReminder(fireDate: date("2026-05-10 09:00"), codepoint: deck.kanji[0].codepoint),
                    ScheduledReminder(fireDate: date("2026-05-10 11:00"), codepoint: deck.kanji[1].codepoint),
                ]
            )
        )
        let ambient = InMemoryStore(AmbientState.empty)

        _ = loop(state: store, ambient: ambient, at: "2026-05-10 09:12").current()

        let arrived = try #require(ambient.value.records[deck.kanji[0].codepoint])
        #expect(arrived.presentationCount == 1)
        #expect(arrived.lastPresentedAt == date("2026-05-10 09:00"))
        #expect(ambient.value.records[deck.kanji[1].codepoint] == nil)
    }

    /// Il primo avvio non ha niente in coda: il kanji lo sceglie il motore, e conta.
    @Test func theFirstKanjiOfAllIsASighting() throws {
        let store = InMemoryStore(ReminderState.empty)
        let ambient = InMemoryStore(AmbientState.empty)

        let snapshot = try #require(loop(state: store, ambient: ambient, at: "2026-05-10 09:12").current())

        #expect(ambient.value.records[snapshot.current.codepoint]?.presentationCount == 1)
        #expect(ambient.value.records.count == 1)
    }

    /// NEXT anticipa la prossima notifica: quel kanji lo stai vedendo adesso, non
    /// all'ora in cui sarebbe arrivato.
    @Test func nextCountsAsASightingNow() throws {
        let store = InMemoryStore(
            ReminderState(
                scheduled: [ScheduledReminder(fireDate: date("2026-05-10 11:00"), codepoint: deck.kanji[1].codepoint)],
                session: StudySession(
                    codepoint: deck.kanji[0].codepoint, isDone: false, since: date("2026-05-10 09:00"))
            )
        )
        let ambient = InMemoryStore(AmbientState.empty)

        _ = loop(state: store, ambient: ambient, at: "2026-05-10 09:12").next(after: deck.kanji[0].codepoint)

        let exposure = try #require(ambient.value.records[deck.kanji[1].codepoint])
        #expect(exposure.presentationCount == 1)
        #expect(exposure.lastPresentedAt == date("2026-05-10 09:12"))
    }

    /// Una notifica arrivata mentre studiavi conta una volta sola, anche se poi
    /// premi NEXT e ti ritrovi davanti proprio quella.
    @Test func aKanjiArrivedWhileStudyingIsNotCountedTwice() throws {
        let store = InMemoryStore(
            ReminderState(
                scheduled: [ScheduledReminder(fireDate: date("2026-05-10 09:00"), codepoint: deck.kanji[1].codepoint)],
                session: StudySession(
                    codepoint: deck.kanji[0].codepoint, isDone: false, since: date("2026-05-10 08:55"))
            )
        )
        let ambient = InMemoryStore(AmbientState.empty)

        _ = loop(state: store, ambient: ambient, at: "2026-05-10 09:12").next(after: deck.kanji[0].codepoint)

        #expect(ambient.value.records[deck.kanji[1].codepoint]?.presentationCount == 1)
    }

    @Test func openingFromANotificationIsAStrongerSignal() throws {
        let store = InMemoryStore(ReminderState.empty)
        let ambient = InMemoryStore(AmbientState.empty)
        let opened = deck.kanji[2].codepoint

        _ = loop(state: store, ambient: ambient, at: "2026-05-10 09:12").open(ReminderDestination(codepoint: opened))

        #expect(ambient.value.records[opened]?.openedCount == 1)
    }

    /// Il giro che conterebbe due volte se non stessimo attenti: la notifica scade,
    /// l'app la recupera, e il tocco sulla notifica apre quel kanji. È una comparsa
    /// e un'apertura, non due comparse.
    @Test func anExpiredNotificationOpenedFromTheWristCountsOnce() throws {
        let arrived = deck.kanji[1].codepoint
        let store = InMemoryStore(
            ReminderState(scheduled: [ScheduledReminder(fireDate: date("2026-05-10 09:00"), codepoint: arrived)])
        )
        let ambient = InMemoryStore(AmbientState.empty)

        _ = loop(state: store, ambient: ambient, at: "2026-05-10 09:12").current()
        _ = loop(state: store, ambient: ambient, at: "2026-05-10 09:13").open(ReminderDestination(codepoint: arrived))

        let exposure = try #require(ambient.value.records[arrived])
        #expect(exposure.presentationCount == 1)
        #expect(exposure.openedCount == 1)
    }

    /// Due recuperi di fila: la seconda volta la notifica non c'è più in coda, quindi
    /// non può essere contata un'altra volta.
    @Test func catchingUpTwiceDoesNotCountTheSameNotificationTwice() throws {
        let arrived = deck.kanji[0].codepoint
        let store = InMemoryStore(
            ReminderState(scheduled: [ScheduledReminder(fireDate: date("2026-05-10 09:00"), codepoint: arrived)])
        )
        let ambient = InMemoryStore(AmbientState.empty)

        _ = loop(state: store, ambient: ambient, at: "2026-05-10 09:12").current()
        _ = loop(state: store, ambient: ambient, at: "2026-05-10 09:13").current()

        #expect(ambient.value.records[arrived]?.presentationCount == 1)
        #expect(store.value.today.count(on: date("2026-05-10 09:13"), calendar: calendar) == 1)
    }

    @Test func readingsPushTheKanjiFurtherAway() throws {
        let store = InMemoryStore(ReminderState.empty)
        let ambient = InMemoryStore(AmbientState.empty)
        let studied = deck.kanji[0].codepoint
        let loop = loop(state: store, ambient: ambient, at: "2026-05-10 09:12")
        _ = loop.open(ReminderDestination(codepoint: studied))
        let before = try #require(ambient.value.records[studied]?.nextDueAt)

        loop.readingsViewed(studied)

        #expect(ambient.value.records[studied]?.readingsViewedCount == 1)
        #expect(try #require(ambient.value.records[studied]?.nextDueAt) > before)
    }

    // MARK: - La forma dice se era una richiesta di aiuto

    /// Il giro che fa nascere il ritmo personale: il kanji arriva da solo, lo tocchi,
    /// arrivi alle letture. Tutti e tre i segnali sanno che era un richiamo.
    @Test func openingAKanjiShownAloneIsRecordedAsARequest() throws {
        let alone = deck.kanji[0].codepoint
        let store = InMemoryStore(
            ReminderState(
                scheduled: [ScheduledReminder(fireDate: date("2026-05-10 09:00"), codepoint: alone, content: .recall)]
            )
        )
        let ambient = InMemoryStore(AmbientState.empty)

        _ = loop(state: store, ambient: ambient, at: "2026-05-10 09:12").current()
        _ = loop(state: store, ambient: ambient, at: "2026-05-10 09:13")
            .open(ReminderDestination(codepoint: alone, content: .recall))
        loop(state: store, ambient: ambient, at: "2026-05-10 09:14").readingsViewed(alone)

        let exposure = try #require(ambient.value.records[alone])
        #expect(exposure.presentationCount == 1)
        // 0.30 per il tocco e 0.25 per le letture, meno il minuto di decadimento
        // passato fra i due: il punteggio invecchia da subito.
        #expect(abs(exposure.supportScore - 0.55) < 0.001)
        #expect(exposure.supportLevel(at: date("2026-05-10 09:14")) == .medium)
    }

    /// Lo stesso giro su un kanji che aveva già il significato sotto non chiede
    /// niente: stavi solo guardando.
    @Test func openingAKanjiWithItsMeaningAsksForNothing() throws {
        let explained = deck.kanji[1].codepoint
        let store = InMemoryStore(
            ReminderState(
                scheduled: [
                    ScheduledReminder(fireDate: date("2026-05-10 09:00"), codepoint: explained, content: .introduce)
                ]
            )
        )
        let ambient = InMemoryStore(AmbientState.empty)

        _ = loop(state: store, ambient: ambient, at: "2026-05-10 09:12").current()
        _ = loop(state: store, ambient: ambient, at: "2026-05-10 09:13")
            .open(ReminderDestination(codepoint: explained, content: .introduce))
        loop(state: store, ambient: ambient, at: "2026-05-10 09:14").readingsViewed(explained)

        #expect(try #require(ambient.value.records[explained]).supportScore == 0)
    }

    /// Le letture prendono la forma dalla sessione in corso, non dall'ultima notifica
    /// che è passata: è quella che hai davanti agli occhi.
    @Test func theReadingsSignalFollowsTheSessionForm() throws {
        let studied = deck.kanji[2].codepoint
        let store = InMemoryStore(
            ReminderState(
                session: StudySession(
                    codepoint: studied, isDone: false, since: date("2026-05-10 09:00"), content: .recall))
        )
        let ambient = InMemoryStore(AmbientState.empty)

        loop(state: store, ambient: ambient, at: "2026-05-10 09:12").readingsViewed(studied)

        #expect(try #require(ambient.value.records[studied]).supportScore == 0.25)
    }

    // MARK: - La forma che viaggia col kanji

    /// La notifica arrivata porta con sé la sua forma: se al polso hai visto la
    /// parola, l'app non riparte dal significato.
    @Test func anArrivedNotificationKeepsItsForm() {
        var value = state(
            scheduled: [ScheduledReminder(fireDate: date("2026-05-10 09:00"), codepoint: "aaaaa", content: .context)]
        )

        value.recordDeliveries(now: date("2026-05-10 09:12"), calendar: calendar)

        #expect(value.session.codepoint == "aaaaa")
        #expect(value.session.content == .context)
    }

    /// NEXT anticipa la notifica intera, non solo il suo kanji.
    @Test func nextPullsTheFormForwardToo() {
        var value = state(
            scheduled: [ScheduledReminder(fireDate: date("2026-05-10 11:00"), codepoint: "bbbbb", content: .recall)],
            session: studying("old00", since: "2026-05-10 09:00")
        )

        let outcome = value.advance(
            after: "old00", now: date("2026-05-10 09:12"), dailyLimit: 10,
            draw: { ReminderDestination(codepoint: "zzzzz") }, calendar: calendar)

        #expect(outcome == .showing("bbbbb"))
        #expect(value.session.content == .recall)
        // E non resta in coda: arriverebbe una seconda volta.
        #expect(value.scheduled.isEmpty)
    }

    /// Il tocco sulla notifica apre nella forma che stavi guardando.
    @Test func openingKeepsTheFormYouWereLookingAt() throws {
        let store = InMemoryStore(ReminderState.empty)
        let ambient = InMemoryStore(AmbientState.empty)
        let destination = ReminderDestination(codepoint: deck.kanji[1].codepoint, content: .context)

        _ = loop(state: store, ambient: ambient, at: "2026-05-10 09:12").open(destination)

        #expect(store.value.session.content == .context)
    }

    /// Sessioni salvate prima della micro-sequenza: si leggono, e valgono come
    /// "kanji e significato".
    @Test func aSessionSavedBeforeTheSequenceIsAnIntroduce() throws {
        let saved = #"{"scheduled":[],"session":{"codepoint":"04e00","isDone":false}}"#
        let value = try JSONDecoder().decode(ReminderState.self, from: Data(saved.utf8))

        #expect(value.session.codepoint == "04e00")
        #expect(value.session.content == .introduce)
    }

    /// Chi arriva da una notifica ricomincia da quel kanji, anche se aveva chiuso il giro.
    @Test func openingANotificationStartsItsKanjiAgain() throws {
        let store = InMemoryStore(
            ReminderState(
                session: StudySession(codepoint: deck.kanji[0].codepoint, isDone: true, since: date("2026-05-10 08:00"))
            )
        )

        let opened = try #require(
            loop(state: store, at: "2026-05-10 09:12").open(ReminderDestination(codepoint: deck.kanji[2].codepoint)))

        #expect(opened.current == deck.kanji[2])
        #expect(!opened.isDone)
        #expect(opened.startedAt == date("2026-05-10 09:12"))
    }
}
