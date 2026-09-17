import SwiftUI

/// Livello 1 dei token: un tema. Colori grezzi, famiglia dei caratteri e modo di
/// disegnare i tratti viaggiano insieme, perché un tema è una scelta sola: il pennello
/// su fondo indaco o i caratteri serif senza carta sarebbero combinazioni mai progettate.
///
/// Le view non leggono il tema direttamente: usano i token semantici di Colors.swift,
/// che lo risolvono dall'ambiente. Si applica una volta, con `dsTheme(_:)`.
public nonisolated struct DSTheme: Identifiable, Equatable, Sendable {
    /// I valori stanno in esadecimale e non in `Color`, così il test sul contrasto può
    /// calcolare la luminanza di ogni tema senza disegnare niente.
    public struct Palette: Equatable, Sendable {
        /// Fondo di ogni schermata.
        public let background: UInt32
        /// Superficie sopra il fondo: riquadri, piani del paywall.
        public let surface: UInt32
        /// Testo primario e tratti già scritti.
        public let ink: UInt32
        /// Testo secondario: letture, didascalie, etichette.
        public let inkSecondary: UInt32
        /// Accento per forme e tratti: il tratto in corso, i bottoni pieni.
        public let accent: UInt32
        /// Accento per il testo piccolo.
        public let accentText: UInt32
        /// Testo sopra l'accento pieno.
        public let onAccent: UInt32
        /// Avvisi: mai da soli, sempre con un'icona o un testo.
        public let warning: UInt32
    }

    public enum Strokes: Equatable, Sendable {
        /// Linea di spessore costante, come i tracciati di KanjiVG.
        case fine
        /// Pennello: lo spessore segue la pressione e la fine del tratto.
        case brush
    }

    /// Coincide col nome del tema salvato nelle impostazioni.
    public let id: String
    public let palette: Palette
    public let fontDesign: Font.Design
    public let strokes: Strokes
    /// Il sigillo col numero dei tratti accanto al kanji.
    public let showsSeal: Bool
    /// Chiaro o scuro. Sui temi chiari l'ora, che il sistema disegna sempre bianca, ha
    /// bisogno di un fondo: lo dà `DSTopWash`.
    public let colorScheme: ColorScheme
}

nonisolated extension DSTheme {
    /// Ai-zome: fondo notte, tratti bianco freddo, accento indaco. Il tema di base.
    public static let aiZome = DSTheme(
        id: "aiZome",
        palette: Palette(
            // Nero bluastro, non nero puro: su OLED resta profondo ma non "buco".
            background: 0x05_070D,
            surface: 0x10_1A2E,
            ink: 0xE8_EEF7,
            inkSecondary: 0x83_91A7,
            // Ai-iro. Contrasto 4.3:1 sul fondo: buono per forme e tratti, sotto soglia
            // per il testo piccolo, e per quello c'è accentText.
            accent: 0x3E_6FD8,
            accentText: 0x8F_AEF0,
            onAccent: 0xE8_EEF7,
            warning: 0xE0_A23E
        ),
        fontDesign: .default,
        strokes: .fine,
        showsSeal: false,
        colorScheme: .dark
    )

    /// Sumi-e su carta washi: inchiostro nero a pennello, rosso shu dei sigilli.
    public static let sumiWashi = DSTheme(
        id: "sumiWashi",
        palette: Palette(
            background: 0xF3_EEE4,
            surface: 0xE4_DDCE,
            ink: 0x1C_1B19,
            inkSecondary: 0x62_5B52,
            accent: 0xC7_3A22,
            accentText: 0xA8_2E19,
            onAccent: 0xF3_EEE4,
            warning: 0x9A_5A00
        ),
        fontDesign: .serif,
        strokes: .brush,
        showsSeal: true,
        colorScheme: .light
    )

    /// Sumi-e su carta senape: lo stesso inchiostro su una carta calda. La superficie è
    /// più chiara del fondo: più scura, il testo secondario dei riquadri non si leggerebbe.
    public static let sumiSenape = DSTheme(
        id: "sumiSenape",
        palette: Palette(
            background: 0xE0_C07A,
            surface: 0xE8_CD8F,
            ink: 0x1C_1B19,
            inkSecondary: 0x57_4B3C,
            accent: 0xB8_2F1C,
            accentText: 0x8E_2414,
            onAccent: 0xF3_EEE4,
            warning: 0x6E_4200
        ),
        fontDesign: .serif,
        strokes: .brush,
        showsSeal: true,
        colorScheme: .light
    )

    public static let all = [aiZome, sumiWashi, sumiSenape]

    /// Un nome sconosciuto, per esempio un tema tolto in un aggiornamento, torna al tema
    /// di base invece di lasciare l'app senza colori.
    public static func named(_ id: String) -> DSTheme {
        all.first { $0.id == id } ?? aiZome
    }
}

nonisolated extension EnvironmentValues {
    @Entry public var dsTheme: DSTheme = .aiZome
}

extension View {
    /// Applica un tema a questa view e a tutto quello che contiene.
    public func dsTheme(_ theme: DSTheme) -> some View {
        environment(\.dsTheme, theme)
            .fontDesign(theme.fontDesign)
    }
}

nonisolated extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
