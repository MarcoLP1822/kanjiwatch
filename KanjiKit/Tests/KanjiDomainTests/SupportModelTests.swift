import Foundation
import Testing

@testable import KanjiDomain

/// Quanto un kanji sembra chiedere un appiglio: non quanto è difficile — quello non
/// lo sappiamo — ma quante volte, vedendolo da solo, sei andato a cercare il resto.
@Suite("Richiesta di supporto")
struct SupportModelTests {
    private let kanji = "08b70"

    private func afterRecall(_ events: [ExposureEvent], at time: String = "2026-05-10 09:00") -> AmbientState {
        var state = AmbientState.empty
        state.record(.presented, codepoint: kanji, content: .recall, at: date(time))
        for event in events {
            state.record(event, codepoint: kanji, content: .recall, at: date(time) + 60)
        }
        return state
    }

    @Test func aFreshKanjiAsksForNothing() {
        var state = AmbientState.empty
        state.record(.presented, codepoint: kanji, content: .recall, at: date("2026-05-10 09:00"))

        #expect(state.records[kanji]?.supportScore == 0)
        #expect(state.support(of: kanji, at: date("2026-05-10 09:00")) == .low)
        #expect(state.records[kanji]?.supportUpdatedAt == nil)
    }

    /// Il kanji era lì da solo e l'hai aperto: è la richiesta.
    @Test func openingAKanjiShownAloneAsksForSupport() throws {
        let state = afterRecall([.opened])
        let exposure = try #require(state.records[kanji])

        #expect(exposure.supportScore == 0.30)
        #expect(exposure.supportUpdatedAt == date("2026-05-10 09:01"))
        #expect(exposure.supportLevel(at: date("2026-05-10 09:01")) == .medium)
    }

    /// E se poi sei arrivato fino alle letture, la richiesta è confermata.
    @Test func goingAllTheWayAsksForMore() throws {
        let state = afterRecall([.opened, .readingsViewed])
        let exposure = try #require(state.records[kanji])

        #expect(exposure.supportScore == 0.55)
        #expect(exposure.supportLevel(at: date("2026-05-10 09:01")) == .medium)
    }

    /// Aprire un kanji che aveva già il significato scritto sotto non chiede niente:
    /// è il comportamento normale di chi sta guardando.
    @Test func openingAnIntroduceOrAContextMeansNothing() {
        for content in [ExposureContent.introduce, .context] {
            var state = AmbientState.empty
            state.record(.presented, codepoint: kanji, content: content, at: date("2026-05-10 09:00"))
            state.record(.opened, codepoint: kanji, content: content, at: date("2026-05-10 09:01"))
            state.record(.readingsViewed, codepoint: kanji, content: content, at: date("2026-05-10 09:02"))

            #expect(state.records[kanji]?.supportScore == 0, "\(content) non è una richiesta")
        }
    }

    /// Ignorare una notifica non è "lo conosco": potresti non aver nemmeno guardato
    /// il polso. Il punteggio non scende per assenza di gesti.
    @Test func ignoringANotificationDoesNotLowerAnything() throws {
        var state = afterRecall([.opened])
        state.record(.presented, codepoint: kanji, content: .recall, at: date("2026-05-11 09:00"))

        #expect(try #require(state.records[kanji]).supportScore == 0.30)
    }

    @Test func itNeverGoesAboveOne() throws {
        var state = AmbientState.empty
        for hour in 0..<10 {
            let moment = date("2026-05-10 09:00") + Double(hour) * .hour
            state.record(.presented, codepoint: kanji, content: .recall, at: moment)
            state.record(.opened, codepoint: kanji, content: .recall, at: moment)
            state.record(.readingsViewed, codepoint: kanji, content: .recall, at: moment)
        }

        #expect(try #require(state.records[kanji]).supportScore == 1)
        #expect(state.support(of: kanji, at: date("2026-05-10 18:00")) == .high)
    }

    /// Una fatica di due mesi fa non deve perseguitare un kanji per sempre: il
    /// punteggio si dimezza ogni due settimane.
    @Test func itFadesWithTime() throws {
        let state = afterRecall([.opened, .readingsViewed])
        let exposure = try #require(state.records[kanji])
        let start = date("2026-05-10 09:01")

        #expect(exposure.support(at: start) == 0.55)
        #expect(abs(exposure.support(at: start + 14 * .day) - 0.275) < 0.0001)
        #expect(abs(exposure.support(at: start + 28 * .day) - 0.1375) < 0.0001)
        // E col punteggio torna anche il comportamento: da medium a low.
        #expect(exposure.supportLevel(at: start) == .medium)
        #expect(exposure.supportLevel(at: start + 28 * .day) == .low)
    }

    /// Un segnale nuovo riparte da quello già decaduto, non da quello vecchio pieno.
    @Test func aNewSignalBuildsOnWhatIsLeft() throws {
        var state = afterRecall([.opened, .readingsViewed])
        state.record(.opened, codepoint: kanji, content: .recall, at: date("2026-05-24 09:01"))

        // 0.55 dimezzato in due settimane, più 0.30.
        #expect(abs(try #require(state.records[kanji]).supportScore - 0.575) < 0.0001)
    }

    /// Storici salvati prima del ritmo personale: si leggono, e ripartono da zero
    /// segnali invece di buttare via mesi di esposizioni.
    @Test func aHistorySavedBeforeSupportStillLoads() throws {
        let saved = """
            {"records":{"06c34":{"firstSeenAt":768484800,"lastPresentedAt":768488400,"presentationCount":3,
            "openedCount":1,"readingsViewedCount":1,"nextDueAt":768574800}}}
            """
        let state = try JSONDecoder().decode(AmbientState.self, from: Data(saved.utf8))
        let exposure = try #require(state.records["06c34"])

        #expect(exposure.presentationCount == 3)
        #expect(exposure.supportScore == 0)
        #expect(exposure.supportUpdatedAt == nil)
        #expect(exposure.supportLevel(at: .now) == .low)
    }

    @Test func theSameHistoryGivesTheSameAnswer() {
        #expect(afterRecall([.opened, .readingsViewed]) == afterRecall([.opened, .readingsViewed]))
    }
}
