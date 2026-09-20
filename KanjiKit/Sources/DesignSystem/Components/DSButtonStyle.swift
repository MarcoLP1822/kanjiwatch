import SwiftUI

/// I bottoni dell'app: il primario pieno, per il gesto che ci si aspetta; il
/// secondario solo contornato, così a colpo d'occhio i due non si confondono.
///
/// Fatto qui e non con gli stili di sistema: su watchOS `.bordered` è un
/// riempimento grigio, non un contorno.
public struct DSButtonStyle: ButtonStyle {
    public enum Prominence: Sendable {
        case primary
        case secondary
    }

    private let prominence: Prominence

    public init(_ prominence: Prominence) {
        self.prominence = prominence
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.dsButton)
            .foregroundStyle(prominence == .primary ? DSColor.dsOnAccent : .dsAccentText)
            .frame(maxWidth: .infinity, minHeight: DS.Control.height)
            .background {
                switch prominence {
                case .primary:
                    Capsule().fill(.dsAccent)
                case .secondary:
                    Capsule().strokeBorder(.dsAccentText, lineWidth: DS.Control.borderWidth)
                }
            }
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? DS.Control.pressedOpacity : 1)
    }
}

extension ButtonStyle where Self == DSButtonStyle {
    public static var dsPrimary: DSButtonStyle { DSButtonStyle(.primary) }
    public static var dsSecondary: DSButtonStyle { DSButtonStyle(.secondary) }
}

/// Un'area da toccare con la semantica di un bottone ma senza il suo aspetto: su watchOS
/// lo stile di sistema impone sfondo e margini e si mangerebbe il quadrante. È un bottone
/// vero, e non un tocco su una view, perché VoiceOver lo annunci e lo attivi come tale.
public struct DSTapAreaStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(.rect)
            .opacity(configuration.isPressed ? DS.Control.tapAreaPressedOpacity : 1)
    }
}

extension ButtonStyle where Self == DSTapAreaStyle {
    public static var dsTapArea: DSTapAreaStyle { DSTapAreaStyle() }
}
