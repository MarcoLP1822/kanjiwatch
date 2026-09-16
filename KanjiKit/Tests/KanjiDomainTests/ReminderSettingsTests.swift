import Foundation
import Testing

@testable import KanjiDomain

@Suite("Impostazioni salvate")
struct ReminderSettingsTests {
    /// Impostazioni scritte prima che esistessero i mazzi: il campo nuovo manca, e
    /// non deve costare all'utente intervallo e fascia oraria.
    @Test func settingsSavedBeforeDecksKeepTheirValues() throws {
        let saved = #"{"intervalMinutes":90,"activeHours":{"startHour":7,"endHour":23},"isPassive":true}"#

        let settings = try JSONDecoder().decode(ReminderSettings.self, from: Data(saved.utf8))

        #expect(settings.intervalMinutes == 90)
        #expect(settings.activeHours == ActiveHours(startHour: 7, endHour: 23))
        #expect(settings.isPassive)
        #expect(settings.grades == KanjiLevel.freeGrades)
    }

    @Test func gradesSurviveSavingAndReloading() throws {
        var settings = ReminderSettings.default
        settings.grades = [1, 2, 3, 8]

        let reloaded = try JSONDecoder().decode(ReminderSettings.self, from: JSONEncoder().encode(settings))

        #expect(reloaded == settings)
    }

    @Test func onlyTheFirstTwoGradesAreFree() {
        #expect(KanjiLevel(grade: 1, count: 80).isFree)
        #expect(KanjiLevel(grade: 2, count: 160).isFree)
        #expect(!KanjiLevel(grade: 3, count: 200).isFree)
        #expect(!KanjiLevel(grade: 8, count: 1110).isFree)
    }
}
