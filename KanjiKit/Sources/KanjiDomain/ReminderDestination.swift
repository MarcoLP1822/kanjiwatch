import Foundation

/// Quale kanji, e in che forma. È la coppia che deve viaggiare **insieme**: dalla
/// coda alla notifica, dalla notifica al tocco, dal quadrante al link che apre l'app.
///
/// Separarli era il modo sicuro di ritrovarsi con una notifica che mostra 水曜日 e
/// un'app che, aperta da quella notifica, riparte da «水 — water».
public struct ReminderDestination: Equatable, Sendable, Codable {
    public let codepoint: String
    public let content: ExposureContent

    public init(codepoint: String, content: ExposureContent = .introduce) {
        self.codepoint = codepoint
        self.content = content
    }
}

extension ScheduledReminder {
    public var destination: ReminderDestination {
        ReminderDestination(codepoint: codepoint, content: content)
    }
}
