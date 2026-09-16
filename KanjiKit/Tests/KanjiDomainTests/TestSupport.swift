import Foundation

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

/// Generatore deterministico: i test sul mescolamento non possono dipendere dalla
/// fortuna del momento.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407 }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
