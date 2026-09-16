import Foundation
import Testing

@testable import KanjiDomain

@Suite("Ciclo del mazzo")
struct DeckCycleTests {
    private let deck = ["a", "b", "c", "d", "e"]

    @Test func showsEveryKanjiBeforeRepeatingOne() {
        var generator = SeededGenerator(seed: 42)
        var cycle = DeckCycle(codepoints: deck, using: &generator)

        let firstRound = (0..<deck.count).compactMap { _ in cycle.next(using: &generator) }
        #expect(Set(firstRound) == Set(deck))
        #expect(firstRound.count == deck.count)
    }

    @Test func reshufflesWithoutRepeatingTheLastOne() {
        for seed in UInt64(1)...25 {
            var generator = SeededGenerator(seed: seed)
            var cycle = DeckCycle(codepoints: deck, using: &generator)
            let firstRound = (0..<deck.count).compactMap { _ in cycle.next(using: &generator) }
            let openingTheNextRound = cycle.next(using: &generator)
            #expect(openingTheNextRound != firstRound.last, "doppione a cavallo del rimescolamento (seed \(seed))")
        }
    }

    @Test func anEmptyDeckGivesNothingInsteadOfCrashing() {
        var generator = SeededGenerator(seed: 1)
        var cycle = DeckCycle(codepoints: [], using: &generator)
        #expect(cycle.next(using: &generator) == nil)
    }

    /// Un aggiornamento dell'app può cambiare il mazzo sotto i piedi del ciclo.
    @Test func reconcileDropsMissingKanjiAndAppendsNewOnes() {
        var generator = SeededGenerator(seed: 7)
        var cycle = DeckCycle(order: ["a", "b", "c", "d"], position: 2)

        cycle.reconcile(with: ["a", "c", "d", "x", "y"], using: &generator)

        #expect(Set(cycle.order) == Set(["a", "c", "d", "x", "y"]))
        // "b" stava prima della posizione corrente: togliendolo, la posizione
        // arretra di uno e il prossimo resta "d", che era quello che toccava.
        #expect(cycle.position == 1)
        #expect(cycle.next(using: &generator) == "c")
    }

    @Test func survivesBeingSavedAndReloaded() throws {
        var generator = SeededGenerator(seed: 3)
        var cycle = DeckCycle(codepoints: deck, using: &generator)
        _ = cycle.next(using: &generator)
        _ = cycle.next(using: &generator)

        let reloaded = try JSONDecoder().decode(DeckCycle.self, from: JSONEncoder().encode(cycle))
        #expect(reloaded == cycle)
        #expect(reloaded.position == 2)
    }
}
