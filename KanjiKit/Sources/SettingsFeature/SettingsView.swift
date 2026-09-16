import DesignSystem
import Foundation
import KanjiDomain
import SwiftUI

/// Le impostazioni. Qui i controlli sono quelli di sistema di proposito: un
/// Picker o un Toggle fatti in casa, su watchOS, si comportano peggio e basta.
public struct SettingsView: View {
    @Bindable private var model: SettingsViewModel
    private let attribution: String

    public init(model: SettingsViewModel, attribution: String) {
        self.model = model
        self.attribution = attribution
    }

    public var body: some View {
        Form {
            Section {
                ForEach(model.levels) { level in
                    Toggle(isOn: deckBinding(for: level)) {
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            levelName(level)
                            Text(verbatim: "\(level.count) kanji")
                                .font(.dsLabel)
                                .foregroundStyle(.dsInkSecondary)
                        }
                    }
                }
            } header: {
                Text("Decks", bundle: .module)
            }

            Section {
                Picker(selection: $model.intervalMinutes) {
                    ForEach(ReminderSettings.offeredIntervals, id: \.self) { minutes in
                        Text(verbatim: intervalLabel(minutes)).tag(minutes)
                    }
                } label: {
                    Text("Interval", bundle: .module)
                }
            } header: {
                Text("Reminders", bundle: .module)
            }

            Section {
                hourPicker(Text("From", bundle: .module), selection: $model.startHour)
                hourPicker(Text("To", bundle: .module), selection: $model.endHour)
            } header: {
                Text("Active hours", bundle: .module)
            } footer: {
                Text("Outside this window nothing arrives.", bundle: .module)
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
