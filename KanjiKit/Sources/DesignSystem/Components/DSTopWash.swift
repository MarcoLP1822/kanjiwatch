import SwiftUI

/// Un velo d'inchiostro lungo il bordo superiore, solo sui temi chiari.
///
/// L'ora in alto la disegna watchOS, sempre bianca, e sulla carta sparirebbe; il
/// sistema non permette di cambiarle colore. Il velo le dà un fondo scuro, come
/// l'acquerello che sfuma sul bordo di un rotolo. Sui temi scuri non serve e non c'è.
public struct DSTopWash: View {
    @Environment(\.dsTheme) private var theme

    public init() {}

    public var body: some View {
        if theme.colorScheme == .light {
            LinearGradient(
                stops: [
                    .init(color: theme.color(.ink).opacity(0.72), location: 0),
                    .init(color: theme.color(.ink).opacity(0.42), location: 0.5),
                    .init(color: theme.color(.ink).opacity(0), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: DS.Control.height + DS.Spacing.l)
            .frame(maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}
