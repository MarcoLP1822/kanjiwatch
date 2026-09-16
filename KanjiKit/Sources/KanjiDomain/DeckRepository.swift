import Foundation

/// Un livello del mazzo: un grado scolastico giapponese.
///
/// I gradi 1-6 sono le elementari (1.026 kanji), l'8 sono le superiori: insieme
/// fanno i 2.136 jōyō. Sono i mazzi che si scelgono, perché con un unico mazzo
/// mescolato di duemila kanji un giro completo durerebbe mesi.
public struct KanjiLevel: Equatable, Hashable, Sendable, Identifiable {
    public let grade: Int
    public let count: Int

    public var id: Int { grade }

    public init(grade: Int, count: Int) {
        self.grade = grade
        self.count = count
    }

    /// Le prime due classi sono il mazzo gratuito: 240 kanji, abbastanza per
    /// settimane d'uso vero e per capire se il metodo funziona.
    public static let freeGrades: Set<Int> = [1, 2]

    public var isFree: Bool { Self.freeGrades.contains(grade) }
}

/// Cosa c'è nel bundle, senza caricare un solo kanji.
public struct DeckCatalog: Equatable, Sendable {
    /// Lato del quadrato in cui vivono i tracciati: KanjiVG usa 109.
    public let viewBox: Double
    /// Testo di licenza: CC BY-SA obbliga a mostrarlo dentro l'app.
    public let attribution: String
    public let levels: [KanjiLevel]

    public init(viewBox: Double, attribution: String, levels: [KanjiLevel]) {
        self.viewBox = viewBox
        self.attribution = attribution
        self.levels = levels
    }

    public var totalCount: Int { levels.reduce(0) { $0 + $1.count } }
}

/// Da dove arriva il mazzo. Il dominio non sa se è un file nel bundle, la rete
/// o un array scritto a mano in un test: sa solo che può chiederlo.
public protocol DeckRepository {
    func loadCatalog() throws -> DeckCatalog
    /// Solo i gradi richiesti. Decodificare tutti i 2.136 jōyō costa mezzo secondo
    /// sul Watch; i 240 del mazzo gratuito, un decimo.
    func loadDeck(grades: Set<Int>) throws -> KanjiDeck
}
