import Foundation
import KanjiDomain

/// Fuso fisso a Roma: i test sugli orari non possono cambiare risultato a seconda
/// della macchina che li esegue.
let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Rome")!
    calendar.locale = Locale(identifier: "en_US_POSIX")
    return calendar
}()

func date(_ text: String) -> Date {
    formatter.date(from: text)!
}

func label(_ value: Date) -> String {
    formatter.string(from: value)
}

private let formatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.timeZone = calendar.timeZone
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd HH:mm"
    return formatter
}()

/// Un mazzo finto con codepoint prevedibili e frequenza crescente: così l'ordine con
/// cui l'Ambient Engine introduce i kanji nuovi si legge a occhio nei test.
func testDeck(count: Int, grade: (Int) -> Int = { _ in 1 }) -> KanjiDeck {
    KanjiDeck(
        viewBox: 109,
        attribution: "",
        kanji: (0..<count).map { index in
            Kanji(
                character: String(UnicodeScalar(0x4E00 + index)!),
                codepoint: testCodepoint(index),
                strokes: ["M0,0"],
                onReadings: [],
                kunReadings: [],
                meanings: ["kanji \(index)"],
                grade: grade(index),
                frequencyRank: index + 1
            )
        }
    )
}

func testCodepoint(_ index: Int) -> String {
    String(format: "%05x", 0x4E00 + index)
}

final class FakeScheduler: ReminderScheduling {
    var notifications: [PlannedNotification] = []
    var isPassive = false
    var cancelledAll = false

    func replacePending(with notifications: [PlannedNotification], isPassive: Bool) async {
        self.notifications = notifications
        self.isPassive = isPassive
    }

    func cancelAll() async {
        cancelledAll = true
        notifications = []
    }
}

final class FakeAuthorizer: NotificationAuthorizing {
    var status: NotificationAuthorization
    init(_ status: NotificationAuthorization) { self.status = status }
    func authorizationStatus() async -> NotificationAuthorization { status }
    func requestAuthorization() async -> Bool { status == .authorized }
}
