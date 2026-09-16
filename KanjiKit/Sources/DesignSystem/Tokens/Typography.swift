import SwiftUI

/// Livello 2 dei token, tipografia. Tutto parte dagli stili di sistema, così il
/// Dynamic Type continua a funzionare: mai `.system(size:)` fisso nelle view.
extension Font {
    /// Il significato in cima alla schermata delle letture.
    public static let dsTitle = Font.system(.title3, weight: .semibold)
    /// Testo corrente.
    public static let dsBody = Font.system(.body)
    /// Letture in kana: un gradino più grandi del corpo, si leggono al volo.
    public static let dsReading = Font.system(.title3)
    /// La parola di esempio.
    public static let dsWord = Font.system(.headline)
    /// Il testo dei bottoni: grassetto perché, su indaco pieno, il contrasto regge
    /// solo come testo grande (vedi TokenContrastTests).
    public static let dsButton = Font.system(.body, weight: .semibold)
    /// Etichette brevi: ON, KUN, numero di tratti.
    public static let dsLabel = Font.system(.caption2, weight: .semibold)
}

extension View {
    /// Forza la composizione giapponese. Senza, su un orologio in italiano il sistema
    /// può disegnare i kanji con le forme cinesi (直, 骨, 角 cambiano davvero).
    public func dsJapanese() -> some View {
        typesettingLanguage(Locale.Language(identifier: "ja"))
    }
}
