import Foundation
import KanjiDomain

/// Carica il mazzo dal bundle del modulo: un catalogo minuscolo e un file per
/// grado scolastico.
///
/// Misurato su un Mac Intel: tutti i 2.136 jōyō in un colpo si decodificano in
/// 160-300 ms, il mazzo gratuito (gradi 1-2) in 34. Sul Watch va moltiplicato per
/// 3-5, ed è per questo che si carica solo quello che l'utente ripassa.
public struct BundledDeckRepository: DeckRepository {
    private let bundle: Bundle

    public init() {
        self.bundle = .module
    }

    /// Per i test: permette di puntare a un bundle con dati finti.
    init(bundle: Bundle) {
        self.bundle = bundle
    }

    public func loadCatalog() throws -> DeckCatalog {
        try decode(CatalogFile.self, resource: "kanji-catalog").toDomain()
    }

    public func loadDeck(grades: Set<Int>) throws -> KanjiDeck {
        let catalog = try loadCatalog()
        let kanji = try catalog.levels
            .filter { grades.contains($0.grade) }
            .flatMap { level in
                try decode(LevelFile.self, resource: "kanji-grade-\(level.grade)").kanji.map { $0.toDomain() }
            }
        return KanjiDeck(viewBox: catalog.viewBox, attribution: catalog.attribution, kanji: kanji)
    }

    /// Tutti i gradi: per i test che devono controllare ogni singolo tratto.
    public func loadDeck() throws -> KanjiDeck {
        try loadDeck(grades: Set(loadCatalog().levels.map(\.grade)))
    }

    private func decode<File: Decodable>(_ type: File.Type, resource: String) throws -> File {
        guard let url = bundle.url(forResource: resource, withExtension: "json") else {
            throw DeckLoadingError.fileMissing(resource)
        }
        return try JSONDecoder().decode(type, from: Data(contentsOf: url))
    }
}

public enum DeckLoadingError: Error, Equatable {
    /// Un file del mazzo non è nel bundle: build rotta, non un errore che l'utente
    /// possa risolvere.
    case fileMissing(String)
}
