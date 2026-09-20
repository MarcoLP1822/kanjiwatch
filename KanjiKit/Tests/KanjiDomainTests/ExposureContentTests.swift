import Foundation
import Testing

@testable import KanjiDomain

@Suite("Forma dell'esposizione")
struct ExposureContentTests {
    private func content(_ sightings: Int, hasWord: Bool = true) -> ExposureContent {
        ExposureContent.forSightings(sightings, hasWord: hasWord)
    }

    /// Le prime tre volte insegnano: questo vuol dire, prova a ricordartelo, eccolo
    /// dentro una parola vera.
    @Test func theFirstThreeSightingsAreTheSequence() {
        #expect(content(0) == .introduce)
        #expect(content(1) == .recall)
        #expect(content(2) == .context)
    }

    /// Dalla quarta in poi il giro si ripete: richiamo, parola, richiamo, e ogni
    /// tanto di nuovo il significato per intero.
    @Test func afterTheThirdItRepeatsAFixedCycle() {
        #expect(
            (3...10).map { content($0) } == [
                .recall, .context, .recall, .introduce,
                .recall, .context, .recall, .introduce,
            ])
    }

    /// JMdict non ha una parola per ogni kanji: senza parola non c'è contesto, e
    /// mostrare una schermata vuota sarebbe peggio che ripetere il significato.
    @Test func withoutAnExampleWordContextBecomesIntroduce() {
        #expect(content(2, hasWord: false) == .introduce)
        #expect(content(4, hasWord: false) == .introduce)
        // Il resto del giro non cambia.
        #expect(content(3, hasWord: false) == .recall)
        #expect(content(6, hasWord: false) == .introduce)
    }

    /// Code programmate prima della micro-sequenza: erano tutte "kanji e significato",
    /// e devono restare leggibili invece di far ripartire l'app da zero.
    @Test func aReminderSavedWithoutAContentIsAnIntroduce() throws {
        let saved = #"{"fireDate":768484800,"codepoint":"06c34"}"#
        let reminder = try JSONDecoder().decode(ScheduledReminder.self, from: Data(saved.utf8))

        #expect(reminder.codepoint == "06c34")
        #expect(reminder.content == .introduce)
    }

    @Test func aReminderKeepsItsContentAcrossASave() throws {
        let reminder = ScheduledReminder(fireDate: date("2026-05-10 09:00"), codepoint: "06c34", content: .context)
        let data = try JSONEncoder().encode(reminder)
        #expect(try JSONDecoder().decode(ScheduledReminder.self, from: data) == reminder)
    }
}
