import Foundation
@testable import KanjiDomain
import Testing

@testable import KanjiData

/// Il motore alla prova delle settimane: ciclo di studio, rischedulazione e stato
/// salvato veri, sul mazzo vero, con un orologio finto che va di notifica in notifica.
///
/// Gli altri test guardano una regola alla volta; questo guarda cosa ne esce dopo
/// giorni. Tre difetti li ha trovati solo una simulazione così: il ritmo che ripartiva
/// a ogni apertura dell'app, i ripassi che dopo una settimana non bastavano più, la coda
/// che finiva per chi l'app non la apre mai.
@Suite("Simulazione di settimane")
struct EngineSimulationTests {
    private final class Clock {
        var now: Date
        init(_ now: Date) { self.now = now }
    }

    private struct NoScheduler: ReminderScheduling {
        func replacePending(with notifications: [PlannedNotification], isPassive: Bool) async {}
        func cancelAll() async {}
    }

    private struct Allowed: NotificationAuthorizing {
        func authorizationStatus() async -> NotificationAuthorization { .authorized }
        func requestAuthorization() async -> Bool { true }
    }

    private struct Day {
        var contacts = 0
        var new = 0
        var distinct = 0
        var mostRepeated = 0
        /// Kanji già visti, e quanti di loro indietro di più di un giorno a fine giornata.
        var seen = 0
        var behind = 0
    }

    private enum Use {
        /// Apre ogni notifica e arriva alle letture.
        case opensEach
        /// Guarda la notifica; l'app la apre la sera, o mai.
        case looks(opensInTheEvening: Bool)
    }

    private func simulate(
        premium: Bool, every minutes: Int, perDay: Int, newPerDay: Int, days: Int, use: Use
    ) async throws -> [Day] {
        let deck = try BundledDeckRepository().loadDeck(grades: [1, 2])
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Rome")!
        let firstDay = calendar.date(from: DateComponents(year: 2026, month: 9, day: 28))!
        let clock = Clock(firstDay.addingTimeInterval(7 * 3600 + 50 * 60))

        var base = ReminderSettings.default
        base.intervalMinutes = minutes
        base.dailyLimit = perDay
        base.newKanjiPerDay = newPerDay
        let status: SubscriptionStatus = premium ? .premium : .free
        let settings = PolicyAppliedSettings(base: InMemoryStore(base), status: { status })
        let state = InMemoryStore(ReminderState.empty)
        let ambient = InMemoryStore(AmbientState.empty)
        let mode: AmbientMode = premium ? .adaptive : .standard
        let cal = calendar
        let loop = StudyLoop(
            deck: deck, settings: settings, state: state, ambient: ambient, mode: { mode },
            nextPastLimit: { premium }, now: { clock.now }, calendar: cal)
        let reschedule = RescheduleReminders(
            deck: deck, settings: settings, state: state, ambient: ambient, mode: { mode },
            scheduler: NoScheduler(), authorization: Allowed(), now: { clock.now }, calendar: cal)
        func day(of date: Date) -> Int { cal.dateComponents([.day], from: firstDay, to: date).day! }

        // Quello che l'utente ha visto davvero: lo storico dell'app lo scopre solo quando
        // la coda si rifà, questo a ogni notifica.
        var seen = AmbientState.empty
        var shown: [(day: Int, codepoint: String, isNew: Bool)] = []
        var nightly: [AmbientState] = []
        if let first = loop.current() {
            seen.record(.presented, codepoint: first.current.codepoint, at: clock.now)
            shown.append((0, first.current.codepoint, true))
        }
        await reschedule.execute()

        let end = cal.date(byAdding: .day, value: days, to: firstDay)!
        var wake = clock.now.addingTimeInterval(4 * 3600)
        var openedOn = Set<Int>()
        while clock.now < end {
            let next = state.load().scheduled.filter { $0.fireDate > clock.now }.min { $0.fireDate < $1.fireDate }
            let today = day(of: clock.now)
            let evening = cal.date(byAdding: .minute, value: (today * 24 + 21) * 60 + 30, to: firstDay)!
            if case .looks(true) = use, !openedOn.contains(today), evening > clock.now,
                next.map({ evening < $0.fireDate }) ?? true
            {
                clock.now = evening
                openedOn.insert(today)
                _ = loop.current()
                await reschedule.execute()
                continue
            }
            // Il risveglio in background dell'app: ogni quattro ore la coda si rifà.
            if next.map({ wake < $0.fireDate }) ?? true {
                clock.now = wake
                wake = wake.addingTimeInterval(4 * 3600)
                if clock.now < end { await reschedule.execute() }
                continue
            }
            guard let next else { break }

            clock.now = next.fireDate
            while nightly.count < day(of: next.fireDate) { nightly.append(seen) }
            shown.append((day(of: next.fireDate), next.codepoint, seen.records[next.codepoint] == nil))
            seen.record(.presented, codepoint: next.codepoint, content: next.content, at: next.fireDate)
            if case .opensEach = use {
                clock.now += 30
                _ = loop.open(next.destination)
                seen.record(.opened, codepoint: next.codepoint, content: next.content, at: clock.now)
                clock.now += 30
                loop.readingsViewed(next.codepoint)
                seen.record(.readingsViewed, codepoint: next.codepoint, content: next.content, at: clock.now)
                _ = loop.done(next.codepoint)
                await reschedule.execute()
            }
        }
        while nightly.count < days { nightly.append(seen) }

        return (0..<days).map { d in
            let today = shown.filter { $0.day == d }
            let repeats = Dictionary(grouping: today, by: \.codepoint).mapValues(\.count)
            let midnight = cal.date(byAdding: .day, value: d + 1, to: firstDay)!
            return Day(
                contacts: today.count,
                new: today.count { $0.isNew },
                distinct: repeats.count,
                mostRepeated: repeats.values.max() ?? 0,
                seen: nightly[d].records.count,
                behind: AmbientEngine.backlog(nightly[d], at: midnight, mode: mode)
            )
        }
    }

    /// Ogni 15 minuti, 30 al giorno, 10 nuovi, l'app aperta a ogni notifica: dal secondo
    /// giorno nessun kanji torna più di due volte, e i nuovi arrivano pieni. Prima il
    /// ritmo ripartiva a ogni apertura e uscivano solo 日 e 一.
    @Test func aHeavyUserSeesVarietyEveryDay() async throws {
        let days = try await simulate(premium: true, every: 15, perDay: 30, newPerDay: 10, days: 5, use: .opensEach)
        for day in days.dropFirst() {
            #expect(day.contacts == 30)
            #expect(day.mostRepeated <= 2)
            #expect(day.new >= 9)
            #expect(day.behind == 0)
        }
    }

    /// Dieci al giorno, l'app aperta la sera: dopo un mese i kanji indietro restano
    /// pochi. Senza il freno ai nuovi erano 64 su 91.
    @Test func aTypicalUserDoesNotFallBehind() async throws {
        let days = try await simulate(
            premium: false, every: 60, perDay: 10, newPerDay: 3, days: 30, use: .looks(opensInTheEvening: true))
        let last = try #require(days.last)
        #expect(last.behind <= 10)
        #expect(last.seen >= 40)
        #expect(days.allSatisfy { $0.contacts == 10 })
    }

    /// Chi guarda le notifiche e non apre mai l'app continua a riceverle: il risveglio in
    /// background rifà la coda. Senza, dopo sei giorni non arrivava più niente.
    @Test func whoNeverOpensTheAppStillGetsKanji() async throws {
        let days = try await simulate(
            premium: false, every: 60, perDay: 10, newPerDay: 3, days: 10, use: .looks(opensInTheEvening: false))
        #expect(days.allSatisfy { $0.contacts == 10 })
    }
}
