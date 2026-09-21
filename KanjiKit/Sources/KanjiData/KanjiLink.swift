import Foundation
import KanjiDomain

/// Il collegamento che apre l'app su un kanji, nella forma in cui lo stai guardando
/// sul quadrante. Lo costruisce la complication e lo legge l'app: il formato sta
/// scritto qui una volta sola.
///
///     kanjiwatch://kanji/06c34?content=context&wi=1
public enum KanjiLink {
    private static let scheme = "kanjiwatch"
    private static let host = "kanji"
    private static let contentKey = "content"
    private static let wordKey = "wi"

    public static func url(for destination: ReminderDestination) -> URL {
        var query = "\(contentKey)=\(destination.content.rawValue)"
        if case .word(let index) = destination.reference {
            query += "&\(wordKey)=\(index)"
        }
        // Un codepoint è esadecimale, la forma è una parola sola e l'indice un numero:
        // l'indirizzo è sempre valido.
        return URL(string: "\(scheme)://\(host)/\(destination.codepoint)?\(query)")!
    }

    public static func destination(from url: URL) -> ReminderDestination? {
        guard url.scheme == scheme, url.host() == host else { return nil }
        let codepoint = url.lastPathComponent
        guard !codepoint.isEmpty, codepoint != "/" else { return nil }

        // Un link vecchio, senza forma o senza parola, apre come apriva prima.
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let value = { (name: String) in items.first { $0.name == name }?.value }
        let content = value(contentKey).flatMap(ExposureContent.init(rawValue:)) ?? .introduce
        let reference = value(wordKey).flatMap(Int.init).map(ExposureReference.word) ?? .none
        return ReminderDestination(codepoint: codepoint, content: content, reference: reference)
    }
}
