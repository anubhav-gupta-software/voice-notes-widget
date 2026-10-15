import SwiftUI
import WidgetKit

struct VoiceNotesEntry: TimelineEntry {
    let date: Date
}

struct VoiceNotesProvider: TimelineProvider {
    func placeholder(in context: Context) -> VoiceNotesEntry {
        VoiceNotesEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (VoiceNotesEntry) -> Void) {
        completion(VoiceNotesEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VoiceNotesEntry>) -> Void) {
        let entry = VoiceNotesEntry(date: .now)
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct VoiceNotesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "VoiceNotesWidget", provider: VoiceNotesProvider()) { _ in
            Text("Voice Note")
                .font(.system(.headline, design: .rounded))
                .containerBackground(Color(red: 0.11, green: 0.09, blue: 0.08), for: .widget)
                .foregroundStyle(Color(red: 0.96, green: 0.95, blue: 0.91))
        }
        .configurationDisplayName("Voice Note")
        .description("The latest note from a friend.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct VoiceNotesWidgetBundle: WidgetBundle {
    var body: some Widget {
        VoiceNotesWidget()
    }
}
