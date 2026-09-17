import DesignSystem
import Foundation
import KanjiDomain
import SwiftUI

/// Il paywall a misura di quadrante.
///
/// Tiene l'essenziale e quello che Apple chiede sempre: durata, prezzo, rinnovo
/// automatico, periodo di prova, ripristino degli acquisti, condizioni d'uso e
/// privacy raggiungibili.
public struct PaywallView: View {
    private let model: PaywallViewModel
    private let termsURL: URL
    private let privacyURL: URL?
    @Environment(\.dismiss) private var dismiss

    public init(model: PaywallViewModel, termsURL: URL, privacyURL: URL?) {
        self.model = model
        self.termsURL = termsURL
        self.privacyURL = privacyURL
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.l) {
                header

                switch model.phase {
                case .loading:
                    ProgressView()
                        .frame(maxWidth: .infinity)
                case .failed where model.offers.isEmpty:
                    failure
                default:
                    plans
                }

                legal
            }
            .padding(DS.Spacing.m)
        }
        .background(.dsBackground)
        .task { await model.load() }
        .onChange(of: model.isUnlocked) { _, unlocked in
            if unlocked { dismiss() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Text("Kanji Watch Premium", bundle: .module)
                .font(.dsTitle)
                .foregroundStyle(.dsInk)
            benefit(Text("All 2,136 jōyō kanji", bundle: .module))
            benefit(Text("Your own rhythm and hours", bundle: .module))
            benefit(Text("Sumi-e brush ink themes", bundle: .module))
        }
    }

    private func benefit(_ text: Text) -> some View {
        Label {
            text
                .font(.dsLabel)
                .foregroundStyle(.dsInk)
        } icon: {
            Image(systemName: "checkmark")
                .foregroundStyle(.dsAccentText)
        }
    }

    private var plans: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            ForEach(model.offers) { offer in
                PlanRow(offer: offer, savings: model.savings(for: offer), isSelected: model.selectedID == offer.id)
                    .onTapGesture { model.select(offer) }
            }

            Button {
                Task { await model.purchaseSelected() }
            } label: {
                Group {
                    if model.selectedOffer?.trialDays != nil {
                        Text("Start free trial", bundle: .module)
                    } else {
                        Text("Subscribe", bundle: .module)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(DSColor.dsAccent)
            .disabled(model.phase == .purchasing || model.selectedOffer == nil)

            if model.lastAttemptFailed {
                Text("The purchase didn't go through. Try again.", bundle: .module)
                    .font(.dsLabel)
                    .foregroundStyle(.dsWarning)
            }

            if let offer = model.selectedOffer {
                terms(for: offer)
            }

            Button {
                Task { await model.restore() }
            } label: {
                Text("Restore purchases", bundle: .module)
                    .font(.dsLabel)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.dsAccentText)
            .disabled(model.phase == .purchasing)
        }
    }

    /// Le condizioni del piano selezionato, scritte per intero: prova, prezzo per
    /// periodo, rinnovo automatico. Sono obbligatorie, e comunque giuste.
    private func terms(for offer: SubscriptionOffer) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            if let days = offer.trialDays {
                Text("Free for \(days) days, then:", bundle: .module)
            }
            pricePerPeriod(offer)
            Text(
                "Renews automatically until cancelled. Cancel anytime from your Apple account settings.",
                bundle: .module
            )
        }
        .font(.dsLabel)
        .foregroundStyle(.dsInkSecondary)
    }

    private func pricePerPeriod(_ offer: SubscriptionOffer) -> Text {
        switch offer.period {
        case .week: Text("\(offer.localizedPrice) per week", bundle: .module)
        case .month: Text("\(offer.localizedPrice) per month", bundle: .module)
        case .year: Text("\(offer.localizedPrice) per year", bundle: .module)
        }
    }

    private var failure: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Text("Couldn't load the plans.", bundle: .module)
                .font(.dsLabel)
                .foregroundStyle(.dsInkSecondary)
            Button {
                Task { await model.load() }
            } label: {
                Text("Try again", bundle: .module)
            }
        }
    }

    private var legal: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Link(destination: termsURL) { Text("Terms of Use", bundle: .module) }
            if let privacyURL {
                Link(destination: privacyURL) { Text("Privacy Policy", bundle: .module) }
            }
        }
        .font(.dsLabel)
        .foregroundStyle(.dsAccentText)
    }
}

private struct PlanRow: View {
    let offer: SubscriptionOffer
    let savings: Int?
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                periodName
                    .font(.dsBody)
                    .foregroundStyle(.dsInk)
                if let days = offer.trialDays {
                    Text("\(days)-day free trial", bundle: .module)
                        .font(.dsLabel)
                        .foregroundStyle(.dsAccentText)
                } else if let savings {
                    Text("Save \(savings)%", bundle: .module)
                        .font(.dsLabel)
                        .foregroundStyle(.dsAccentText)
                }
            }
            Spacer(minLength: DS.Spacing.s)
            Text(verbatim: offer.localizedPrice)
                .font(.dsBody.monospacedDigit())
                .foregroundStyle(.dsInk)
        }
        .padding(DS.Spacing.m)
        .background(.dsSurface, in: .rect(cornerRadius: DS.Radius.m))
        .overlay {
            RoundedRectangle(cornerRadius: DS.Radius.m)
                .strokeBorder(.dsAccent.opacity(isSelected ? 1 : 0), lineWidth: 2)
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var periodName: Text {
        switch offer.period {
        case .week: Text("Weekly", bundle: .module)
        case .month: Text("Monthly", bundle: .module)
        case .year: Text("Yearly", bundle: .module)
        }
    }
}
