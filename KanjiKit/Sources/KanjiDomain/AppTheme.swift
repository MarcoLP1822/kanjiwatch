import Foundation

/// L'aspetto dell'app. I nomi coincidono con quelli dei temi del design system, che il
/// dominio non conosce: qui c'è solo cosa si può scegliere e cosa è gratis.
public enum AppTheme: String, Codable, CaseIterable, Sendable {
    /// Indaco su notte, linea fine.
    case aiZome
    /// Inchiostro a pennello su carta washi.
    case sumiWashi
    /// Inchiostro a pennello su carta senape.
    case sumiSenape

    /// Il tema di base resta gratuito: i temi sumi-e sono un vantaggio Premium.
    public var isFree: Bool { self == .aiZome }
}
