import Foundation
import KanjiDomain

/// Un valore Codable in un file JSON.
///
/// `UserDefaults` va bene per le due chiavi delle notifiche, che sono poche righe e
/// si leggono a ogni avvio. Lo storico delle esposizioni no: cresce con l'uso — un
/// record per ogni kanji incontrato — e non lo deve leggere nessun altro, nemmeno la
/// complication.
public struct JSONFileStore<Value: Codable>: ValueStore {
    private let url: URL
    private let fallback: Value

    public init(url: URL, default fallback: Value) {
        self.url = url
        self.fallback = fallback
    }

    public func load() -> Value {
        guard let data = try? Data(contentsOf: url) else { return fallback }
        guard let decoded = try? JSONDecoder().decode(Value.self, from: data) else {
            // Illeggibile: si riparte da zero invece di bloccare l'app, ma il file si
            // mette da parte invece di lasciarlo sovrascrivere dal primo salvataggio.
            // È l'unica copia di una storia lunga mesi.
            _ = try? FileManager.default.replaceItemAt(url.appendingPathExtension("broken"), withItemAt: url)
            return fallback
        }
        return decoded
    }

    public func save(_ value: Value) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        let directory = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}

extension JSONFileStore where Value == AmbientState {
    /// In Application Support e non in Documenti: è roba dell'app, non dell'utente.
    public static func ambientState() -> Self {
        Self(url: URL.applicationSupportDirectory.appending(path: "ambient-state.json"), default: .empty)
    }
}
