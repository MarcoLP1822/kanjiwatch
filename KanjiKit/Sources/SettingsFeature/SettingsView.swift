import DesignSystem
import Foundation
import KanjiDomain
import SwiftUI

/// Le impostazioni. Qui i controlli sono quelli di sistema di proposito: un
/// Picker o un Toggle fatti in casa, su watchOS, si comportano peggio e basta.
///
/// La destinazione dell'abbonamento arriva da fuori: questa feature non sa che
/// esiste un paywall, e il paywall non sa che esistono le impostazioni.
public struct SettingsView<Premium: View>: View {
    @Bindable private var model: SettingsViewModel
    private let attribution: String
    private let privacyURL: URL?
    private let premium: () -> Premium

    public init(
        model: SettingsViewModel,
        attribution: String,
        privacyURL: URL?,
        @ViewBuilder premium: @escaping () -> Premium
    ) {
        self.model = model
        self.attribution = attribution
        self.privacyURL = privacyURL
        self.premium = premium
    }

    public var body: some View {
        Form {
            if !model.isPremium {
                Section {
                    NavigationLink(destination: premium) {
                        Label {
                            Text("Unlock all kanji", bundle: .module)
                        } icon: {
                            Image(systemName: "sparkles").foregroundStyle(.dsAccentText)
                        }
                    }
                }
            }

            Section {
                ForEach(model.levels) { level in
                    if model.isLocked(level) {
                        NavigationLink(destination: premium) {
                            deckLabel(level, locked: true)
                        }
                    } else {
                        Toggle(isOn: deckBinding(for: level)) {
                            deckLabel(level, locked: false)
                        }
                    }
                }
            } header: {
                Text("Decks", bundle: .module)
            }

            Section {
                ForEach(AppTheme.allCases, id: \.self) { theme in
                    if model.isLocked(theme) {
                        NavigationLink(destination: premium) {
                            themeLabel(theme, locked: true)
                        }
                    } else {
                        Button {
                            model.setTheme(theme)
                        } label: {
                            themeLabel(theme, locked: false)
                        }
                    }
                }
            } header: {
                Text("Theme", bundle: .module)
            }

            Section {
                if model.isPremium {
                    Picker(selection: $model.intervalMinutes) {
                        ForEach(ReminderSettings.offeredIntervals, id: \.self) { minutes in
                            Text(verbatim: intervalLabel(minutes)).tag(minutes)
                        }
                    } label: {
                        Text("Interval", bundle: .module)
                    }
                    Picker(selection: $model.dailyLimit) {
                        ForEach(ReminderSettings.offeredDailyLimits, id: \.self) { count in
                            Text(count, format: .number).tag(count)
                        }
                    } label: {
                        Text("Reminders per day", bundle: .module)
                    }
                } else {
                    lockedValue(
                        Text("Interval", bundle: .module), value: intervalLabel(model.effective.intervalMinutes))
                    lockedValue(
                        Text("Reminders per day", bundle: .module), value: model.effective.dailyLimit.formatted())
                }
            } header: {
                Text("Reminders", bundle: .module)
            } footer: {
                Text(
                    "Reviews and kanji opened with Next count too. Once the number is reached, reminders stop until tomorrow.",
                    bundle: .module)
            }

            Section {
                if model.isPremium {
                    hourPicker(Text("From", bundle: .module), selection: $model.startHour)
                    hourPicker(Text("To", bundle: .module), selection: $model.endHour)
                } else {
                    lockedValue(Text("From", bundle: .module), value: hourLabel(model.effective.activeHours.startHour))
                    lockedValue(Text("To", bundle: .module), value: hourLabel(model.effective.activeHours.endHour))
                }
            } header: {
                Text("Active hours", bundle: .module)
            } footer: {
                if model.isPremium {
                    Text("Outside this window nothing arrives.", bundle: .module)
                } else {
                    Text("Included with Premium.", bundle: .module)
                }
            }

            Section {
                Toggle(isOn: $model.isPassive) {
                    Text("Discreet mode", bundle: .module)
                }
            } footer: {
                Text("Notifications don't wake the screen: they pile up in the list.", bundle: .module)
            }

            Section {
                permission
            } header: {
                Text("Notifications", bundle: .module)
            }

            Section {
                // Le licenze di KanjiVG ed EDRDG chiedono l'attribuzione dentro l'app; EDRDG
                // accetta per i programmi una schermata a parte, raggiungibile da un menu.
                NavigationLink {
                    DocumentView(text: attribution)
                } label: {
                    Text("Data sources", bundle: .module)
                }
                // App Store vuole l'informativa raggiungibile dentro l'app, non solo online.
                NavigationLink {
                    DocumentView(text: PrivacyPolicy.text, onlineURL: privacyURL)
                } label: {
                    Text("Privacy", bundle: .module)
                }
            }
        }
        .tint(DSColor.dsAccent)
        .task { await model.refreshAuthorization() }
        // Le impostazioni sono controlli di sistema, sempre scuri su watchOS: il tema
        // sumi-e li renderebbe illeggibili. Qui, e nel paywall che si apre da qui,
        // resta il tema di base.
        .dsTheme(.aiZome)
    }

    @ViewBuilder
    private var permission: some View {
        switch model.authorization {
        case .authorized:
            Label {
                Text("Active", bundle: .module)
            } icon: {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.dsAccentText)
            }

        case .notDetermined:
            Button {
                Task { await model.requestAuthorization() }
            } label: {
                Text("Enable notifications", bundle: .module)
            }

        case .denied:
            // Su watchOS non esiste un collegamento alle impostazioni di sistema
            // per una singola app: si può solo dire dove andare.
            Label {
                Text("Turn them on in Settings › Notifications on your Watch.", bundle: .module)
                    .font(.dsLabel)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.dsWarning)
            }
        }
    }

    private func deckLabel(_ level: KanjiLevel, locked: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                levelName(level)
                Text(verbatim: "\(level.count) kanji")
                    .font(.dsLabel)
                    .foregroundStyle(.dsInkSecondary)
            }
            if locked {
                Spacer()
                // Il lucchetto accompagna il colore: lo stato non si affida al solo
                // colore, e VoiceOver lo legge.
                Image(systemName: "lock.fill")
                    .foregroundStyle(.dsInkSecondary)
                    .accessibilityLabel(Text("Included with Premium.", bundle: .module))
            }
        }
    }

    private func themeLabel(_ theme: AppTheme, locked: Bool) -> some View {
        HStack(spacing: DS.Spacing.m) {
            ThemeSwatch(theme: DSTheme.named(theme.rawValue))
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                themeName(theme)
                themeDescription(theme)
                    .font(.dsLabel)
                    .foregroundStyle(.dsInkSecondary)
            }
            Spacer(minLength: 0)
            if locked {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.dsInkSecondary)
                    .accessibilityLabel(Text("Included with Premium.", bundle: .module))
            } else if theme == model.theme {
                Image(systemName: "checkmark")
                    .foregroundStyle(.dsAccentText)
            }
        }
        .accessibilityAddTraits(theme == model.theme && !locked ? .isSelected : [])
    }

    private func themeName(_ theme: AppTheme) -> Text {
        switch theme {
        case .aiZome: Text(verbatim: "Ai-zome")
        case .sumiWashi: Text("Sumi-e washi", bundle: .module)
        case .sumiSenape: Text("Sumi-e mustard", bundle: .module)
        }
    }

    private func themeDescription(_ theme: AppTheme) -> Text {
        switch theme {
        case .aiZome: Text("Indigo on night", bundle: .module)
        case .sumiWashi: Text("Brush ink on washi paper", bundle: .module)
        case .sumiSenape: Text("Brush ink on mustard paper", bundle: .module)
        }
    }

    private func lockedValue(_ label: Text, value: String) -> some View {
        NavigationLink(destination: premium) {
            HStack {
                label
                Spacer()
                Text(verbatim: value).foregroundStyle(.dsInkSecondary)
                Image(systemName: "lock.fill").foregroundStyle(.dsInkSecondary)
            }
        }
    }

    private func deckBinding(for level: KanjiLevel) -> Binding<Bool> {
        Binding(
            get: { model.grades.contains(level.grade) },
            set: { model.setGrade(level.grade, enabled: $0) }
        )
    }

    /// In KANJIDIC i gradi 1-6 sono le classi delle elementari, l'8 i jōyō che si
    /// imparano alle medie e alle superiori.
    private func levelName(_ level: KanjiLevel) -> Text {
        level.grade <= 6
            ? Text("Grade \(level.grade)", bundle: .module)
            : Text("Secondary school", bundle: .module)
    }

    private func hourPicker(_ label: Text, selection: Binding<Int>) -> some View {
        Picker(selection: selection) {
            ForEach(0..<24, id: \.self) { hour in
                Text(verbatim: hourLabel(hour)).tag(hour)
            }
        } label: {
            label
        }
    }

    /// Formattazioni dal sistema: "1 h 30 min" o "8 AM" cambiano con la lingua e
    /// col formato 12/24 ore dell'orologio, e non sono cose da tradurre a mano.
    private func intervalLabel(_ minutes: Int) -> String {
        Duration.seconds(minutes * 60)
            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    private func hourLabel(_ hour: Int) -> String {
        var components = DateComponents()
        components.hour = hour
        components.minute = 0
        let date = Calendar.current.date(from: components) ?? Date()
        return date.formatted(.dateTime.hour())
    }
}

/// Il tema in piccolo: la sua carta, il suo inchiostro e il bordo del suo accento. I
/// colori sono quelli del tema mostrato, non di quello attivo.
private struct ThemeSwatch: View {
    let theme: DSTheme

    var body: some View {
        Text(verbatim: "字")
            .font(.system(.body, design: theme.fontDesign).weight(.semibold))
            .foregroundStyle(theme.color(.ink))
            .frame(width: 30, height: 30)
            .background(theme.color(.background), in: .circle)
            .overlay(Circle().strokeBorder(theme.color(.accent), lineWidth: 2))
            .dsJapanese()
            .accessibilityHidden(true)
    }
}
