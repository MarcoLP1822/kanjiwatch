import Foundation
import KanjiDomain

/// Carica kanji.json dal bundle del modulo.
/// 300 kanji stanno in ~300 KB: si decodifica una volta all'avvio e si tiene in memoria.
/// Se il mazzo cresce oltre i ~500 kanji, qui si spezza in indice + tratti on demand.
public struct BundledDeckRepository: DeckRepository {
    private let bundle: Bundle

    public init() {
        self.bundle = .module
    }

    /// Per i test: permette di puntare a un bundle con dati finti.
    init(bundle: Bundle) {
        self.bundle = bundle
    }

    public func loadDeck() throws -> KanjiDeck {
        guard let url = bundle.url(forResource: "kanji", withExtension: "json") else {
            throw DeckLoadingError.fileMissing
        }
        let file = try JSONDecoder().decode(DeckFile.self, from: try Data(contentsOf: url))
        return file.toDomain()
    }
}

public enum DeckLoadingError: Error {
    /// kanji.json non è nel bundle: build rotta, non un errore che l'utente possa risolvere.
    case fileMissing
}
