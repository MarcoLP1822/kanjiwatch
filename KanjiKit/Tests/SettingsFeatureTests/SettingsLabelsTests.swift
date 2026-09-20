import Foundation
import Testing

@testable import SettingsFeature

/// Le etichette delle impostazioni devono dire quello che il numero fa davvero.
///
/// Fino alla F13 «kanji nuovi al giorno» era vero: ogni notifica pescava un kanji
/// diverso dal mazzo mescolato. Con i ripassi ambientali quel numero conta anche le
/// repliche, e tenere il nome di prima faceva promettere all'app una cosa che non fa.
@Suite("Etichette delle impostazioni")
struct SettingsLabelsTests {
    /// Il catalogo vero nel repository: `Bundle.module` in un test SPM non risolve le
    /// traduzioni con un locale forzato, e quello che conta qui è il file sorgente.
    private func catalog() throws -> [String: Any] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Sources/SettingsFeature/Resources/Localizable.xcstrings")
        let json = try JSONSerialization.jsonObject(with: try Data(contentsOf: url))
        return try #require((json as? [String: Any])?["strings"] as? [String: Any])
    }

    private func italian(_ key: String, in catalog: [String: Any]) -> String? {
        let entry = catalog[key] as? [String: Any]
        let localizations = entry?["localizations"] as? [String: Any]
        let unit = (localizations?["it"] as? [String: Any])?["stringUnit"] as? [String: Any]
        return unit?["value"] as? String
    }

    /// Due numeri, due nomi: quante volte l'app si fa viva, e quanti kanji mai visti
    /// può introdurre la giornata.
    @Test func theTwoDailyNumbersHaveTheirOwnNames() throws {
        let strings = try catalog()

        #expect(italian("Reminders per day", in: strings) == "Promemoria al giorno")
        #expect(italian("New kanji per day", in: strings) == "Kanji nuovi al giorno")
        #expect(
            italian(
                "Reviews and kanji opened with Next count too. "
                    + "Once the number is reached, reminders stop until tomorrow.",
                in: strings
            )?.contains("i kanji nuovi sono quelli mai visti prima") == true
        )
    }
}
