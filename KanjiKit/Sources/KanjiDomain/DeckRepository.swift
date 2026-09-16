import Foundation

/// Da dove arriva il mazzo. Il dominio non sa se è un file nel bundle, la rete
/// o un array scritto a mano in un test: sa solo che può chiederlo.
public protocol DeckRepository {
    func loadDeck() throws -> KanjiDeck
}
