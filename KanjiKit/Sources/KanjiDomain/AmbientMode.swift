import Foundation

/// Come si comporta il motore. Il dominio non sa niente di abbonamenti: sa che può
/// girare in due modi, e chi mette insieme l'app decide quale.
public enum AmbientMode: String, Equatable, Sendable, Codable {
    /// Le regole per tutti: ritmo, tetti e micro-sequenza uguali per chiunque.
    case standard
    /// In più, ogni kanji si fa il suo ritmo a seconda di quanto supporto sembri
    /// chiederti.
    case adaptive
}

/// Quanto quel kanji sembra aver bisogno di un appiglio.
///
/// **Non** è la sua difficoltà: di quella non sappiamo niente, e chiamarla così
/// sarebbe fingere una misura che non abbiamo. È solo il riassunto di un fatto
/// osservabile — quante volte, vedendo il kanji da solo, sei andato a cercare il
/// resto. Non si mostra mai all'utente.
public enum SupportLevel: String, Equatable, Hashable, Sendable, CaseIterable {
    case low
    case medium
    case high
}
