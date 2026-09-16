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
    private let premium: () -> Premium

    public init(model: SettingsViewModel, attribution: String, @ViewBuilder premium: @escaping () -> Premium) {
        self.model = model
        self.attribution = attribution
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
                        Text("New kanji per day", bundle: .module)
                    }
                } else {
                    lockedValue(
                        Text("Interval", bundle: .module), value: intervalLabel(model.effective.intervalMinutes))
                    lockedValue(
                        Text("New kanji per day", bundle: .module), value: model.effective.dailyLimit.formatted())
                }
            } header: {
                Text("Reminders", bundle: .module)
            } footer: {
                Text(
                    "Kanji opened with Next count too. Once the number is reached, reminders stop until tomorrow.",
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
                NavigationLink {
                    DataSourcesView(text: attribution)
                } label: {
                    Text("Data sources", bundle: .module)
                }
            }
        }
        .tint(.dsAccent)
        .task { await model.refreshAuthorization() }
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
