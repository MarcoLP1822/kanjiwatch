import ComplicationFeature
import KanjiData
import KanjiDomain
import SwiftUI
import WidgetKit

/// L'estensione della complication: solo composizione. Cosa disegnare sta in
/// ComplicationFeature, cosa leggere in KanjiData.
@main
struct KanjiComplications: WidgetBundle {
    var body: some Widget {
        KanjiComplication()
    }
}

struct KanjiComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "KanjiComplication", provider: GlanceProvider()) { entry in
            GlanceComplicationView(entry: entry)
        }
        .configurationDisplayName(Text(verbatim: "Kanji Watch"))
        .description(Text("The kanji from your latest reminder."))
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

struct GlanceTimelineEntry: TimelineEntry {
    let date: Date
    let glance: GlanceEntry?
    let viewBox: Double
}

/// Legge la timeline che l'app ha già preparato nel contenitore condiviso. Niente
/// mazzo da caricare: un'estensione ha pochi MB e pochi millisecondi.
struct GlanceProvider: TimelineProvider {
    func placeholder(in context: Context) -> GlanceTimelineEntry {
        sample()
    }

    func getSnapshot(in context: Context, completion: @escaping (GlanceTimelineEntry) -> Void) {
        completion(timeline().last { $0.date <= .now } ?? sample())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GlanceTimelineEntry>) -> Void) {
        let entries = timeline()
        // L'app riscrive la timeline a ogni rischedulazione e la fa ricaricare:
        // `.atEnd` serve solo se l'app resta chiusa più a lungo della coda.
        completion(Timeline(entries: entries.isEmpty ? [sample()] : entries, policy: .atEnd))
    }

    private func timeline() -> [GlanceTimelineEntry] {
        guard let catalog = try? BundledDeckRepository().loadCatalog() else { return [] }
        return UserDefaultsStore<[GlanceEntry]>.complicationTimeline().load().map {
            GlanceTimelineEntry(date: $0.date, glance: $0, viewBox: catalog.viewBox)
        }
    }

    /// Per la galleria dei quadranti e prima che l'app sia mai stata aperta: il primo
    /// kanji della prima classe, che è anche il primo del mazzo gratuito.
    private func sample() -> GlanceTimelineEntry {
        guard let deck = try? BundledDeckRepository().loadDeck(grades: [1]), let first = deck.kanji.first else {
            return GlanceTimelineEntry(date: .now, glance: nil, viewBox: 1)
        }
        return GlanceTimelineEntry(date: .now, glance: GlanceEntry(date: .now, kanji: first), viewBox: deck.viewBox)
    }
}

/// Quale vista va su quale formato del quadrante.
struct GlanceComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: GlanceTimelineEntry

    var body: some View {
        Group {
            if let glance = entry.glance {
                content(for: glance)
                    .widgetURL(KanjiLink.url(for: ReminderDestination(codepoint: glance.codepoint)))
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }

    @ViewBuilder
    private func content(for glance: GlanceEntry) -> some View {
        switch family {
        case .accessoryRectangular:
            GlanceCard(entry: glance, viewBox: entry.viewBox)
        case .accessoryInline:
            Text(verbatim: glance.inlineLabel)
        case .accessoryCorner:
            GlanceGlyph(entry: glance, viewBox: entry.viewBox)
                .widgetLabel(glance.meaning)
        default:
            ZStack {
                AccessoryWidgetBackground()
                GlanceGlyph(entry: glance, viewBox: entry.viewBox)
                    .padding(6)
            }
        }
    }
}
