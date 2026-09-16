import Foundation

/// Il collegamento che apre l'app su un kanji. Lo costruisce la complication e lo
/// legge l'app: il formato sta scritto qui una volta sola.
public enum KanjiLink {
    private static let scheme = "kanjiwatch"
    private static let host = "kanji"

    public static func url(for codepoint: String) -> URL {
        // Un codepoint è esadecimale: l'indirizzo è sempre valido.
        URL(string: "\(scheme)://\(host)/\(codepoint)")!
    }

    public static func codepoint(from url: URL) -> String? {
        guard url.scheme == scheme, url.host() == host else { return nil }
        let codepoint = url.lastPathComponent
        return codepoint.isEmpty || codepoint == "/" ? nil : codepoint
    }
}
