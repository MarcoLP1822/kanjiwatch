import Foundation
import KanjiDomain

/// Il collegamento che apre l'app su un kanji, nella forma in cui lo stai guardando
/// sul quadrante. Lo costruisce la complication e lo legge l'app: il formato sta
/// scritto qui una volta sola.
///
///     kanjiwatch://kanji/06c34?content=context
public enum KanjiLink {
    private static let scheme = "kanjiwatch"
    private static let host = "kanji"
    private static let contentKey = "content"

    public static func url(for destination: ReminderDestination) -> URL {
        // Un codepoint è esadecimale e la forma è una parola sola: l'indirizzo è
        // sempre valido.
        URL(string: "\(scheme)://\(host)/\(destination.codepoint)?\(contentKey)=\(destination.content.rawValue)")!
    }

    public static func destination(from url: URL) -> ReminderDestination? {
        guard url.scheme == scheme, url.host() == host else { return nil }
        let codepoint = url.lastPathComponent
        guard !codepoint.isEmpty, codepoint != "/" else { return nil }

        // Un link vecchio, senza forma, apre come apriva prima.
        let content =
            URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first { $0.name == contentKey }?
            .value
            .flatMap(ExposureContent.init(rawValue:)) ?? .introduce
        return ReminderDestination(codepoint: codepoint, content: content)
    }
}
