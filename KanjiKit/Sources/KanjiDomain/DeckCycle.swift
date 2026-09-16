import Foundation

/// L'ordine in cui escono i kanji: una permutazione del mazzo che si consuma e
/// poi si rimescola.
///
/// Meglio del caso puro per due motivi concreti: niente doppioni ravvicinati, e
/// la garanzia che ogni kanji esca una volta prima che se ne ripeta uno. Con 300
/// kanji e un promemoria all'ora, è un giro completo ogni tre settimane.
public struct DeckCycle: Equatable, Sendable, Codable {
    public private(set) var order: [String]
    public private(set) var position: Int

    public init(codepoints: [String], using generator: inout some RandomNumberGenerator) {
        order = codepoints.shuffled(using: &generator)
        position = 0
    }

    public init(order: [String], position: Int) {
        self.order = order
        self.position = min(max(position, 0), order.count)
    }

    public var isExhausted: Bool { position >= order.count }

    public mutating func next(using generator: inout some RandomNumberGenerator) -> String? {
        guard !order.isEmpty else { return nil }
        if isExhausted { reshuffle(using: &generator) }
        defer { position += 1 }
        return order[position]
    }

    public mutating func next() -> String? {
        var system = SystemRandomNumberGenerator()
        return next(using: &system)
    }

    /// Il mazzo può cambiare con un aggiornamento dell'app: i kanji spariti escono,
    /// i nuovi entrano in coda mescolati, e la posizione si aggiusta per non
    /// saltare né ripetere quello che stava per uscire.
    public mutating func reconcile(with codepoints: [String], using generator: inout some RandomNumberGenerator) {
        let wanted = Set(codepoints)
        let existing = Set(order)
        let removedBefore = order.prefix(position).count { !wanted.contains($0) }

        order = order.filter(wanted.contains) + codepoints.filter { !existing.contains($0) }.shuffled(using: &generator)
        position = min(max(position - removedBefore, 0), order.count)
    }

    /// Rimescolando, l'ultimo del giro appena finito non può ritrovarsi primo:
    /// sarebbe l'unico doppione ravvicinato che la permutazione non impedisce.
    private mutating func reshuffle(using generator: inout some RandomNumberGenerator) {
        let previousLast = order.last
        var shuffled = order.shuffled(using: &generator)
        if shuffled.count > 1, shuffled.first == previousLast {
            shuffled.swapAt(0, shuffled.count - 1)
        }
        order = shuffled
        position = 0
    }
}
