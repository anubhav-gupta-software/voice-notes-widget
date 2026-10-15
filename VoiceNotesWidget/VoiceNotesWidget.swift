import SwiftUI
import WidgetKit

struct LatestNoteEntry: TimelineEntry {
    var date: Date
    var snapshot: WidgetSnapshot?
}

struct LatestNoteProvider: TimelineProvider {
    func placeholder(in context: Context) -> LatestNoteEntry {
        LatestNoteEntry(date: .now, snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (LatestNoteEntry) -> Void) {
        let snapshot = context.isPreview ? WidgetSnapshot.preview : AppGroup.readPayload()?.featured
        completion(LatestNoteEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LatestNoteEntry>) -> Void) {
        let entry = LatestNoteEntry(date: .now, snapshot: AppGroup.readPayload()?.featured)
        let refresh = Date().addingTimeInterval(15 * 60)
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }
}

struct LatestNoteWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var snapshot: WidgetSnapshot?

    var body: some View {
        content
            .widgetURL(link)
            .containerBackground(for: .widget) { background }
    }

    @ViewBuilder
    private var content: some View {
        if let snapshot {
            note(snapshot)
                .privacySensitive()
        } else {
            empty
        }
    }

    @ViewBuilder
    private func note(_ snapshot: WidgetSnapshot) -> some View {
        switch family {
        case .systemMedium:
            medium(snapshot)
        case .accessoryRectangular:
            rectangular(snapshot)
        case .accessoryCircular:
            circular(snapshot)
        case .accessoryInline:
            Text("\(snapshot.friendName) · \(NoteFormat.duration(snapshot.duration))")
        default:
            small(snapshot)
        }
    }

    private func small(_ snapshot: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                AvatarView(name: snapshot.friendName, photoJPEG: snapshot.photoJPEG, size: 36)
                Spacer()
                if !snapshot.isHeard {
                    Circle()
                        .fill(Theme.coral)
                        .frame(width: 8, height: 8)
                }
            }
            Text(snapshot.friendName)
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(primaryText)
                .lineLimit(1)
            subtitle(snapshot)
            Spacer(minLength: 0)
            WaveformView(samples: snapshot.waveform, active: waveColor, inactive: waveColor.opacity(0.85))
                .frame(height: 22)
        }
    }

    private func medium(_ snapshot: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                AvatarView(name: snapshot.friendName, photoJPEG: snapshot.photoJPEG, size: 58)
                VStack(alignment: .leading, spacing: 3) {
                    Text(snapshot.friendName)
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(primaryText)
                        .lineLimit(1)
                    subtitle(snapshot)
                }
                Spacer(minLength: 0)
                Image(systemName: "play.fill")
                    .font(.body.weight(.bold))
                    .foregroundStyle(Theme.widgetInk)
                    .frame(width: 36, height: 36)
                    .background(Theme.coral, in: Circle())
                    .accessibilityHidden(true)
            }
            WaveformView(samples: snapshot.waveform, active: waveColor, inactive: waveColor.opacity(0.9))
                .frame(height: 34)
            HStack {
                Text(snapshot.isHeard ? "Heard" : "Tap to play")
                Spacer()
                Text(NoteFormat.duration(snapshot.duration))
                    .monospacedDigit()
            }
            .font(.caption)
            .foregroundStyle(secondaryText)
        }
    }

    private func rectangular(_ snapshot: WidgetSnapshot) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.friendName)
                    .font(.headline)
                    .lineLimit(1)
                Text(NoteFormat.duration(snapshot.duration))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            WaveformView(samples: snapshot.waveform, active: .primary, inactive: .primary.opacity(0.8))
        }
    }

    private func circular(_ snapshot: WidgetSnapshot) -> some View {
        VStack(spacing: 2) {
            Text(snapshot.initials)
                .font(.system(.headline, design: .rounded))
            Image(systemName: "waveform")
                .font(.caption)
        }
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "waveform")
                .font(.title3)
                .foregroundStyle(onHomeScreen ? Theme.coral : .primary)
            Text("No note yet")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(primaryText)
            if family != .systemSmall && onHomeScreen {
                Text("Record one in Voice Notes.")
                    .font(.caption)
                    .foregroundStyle(secondaryText)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func subtitle(_ snapshot: WidgetSnapshot) -> some View {
        HStack(spacing: 4) {
            if snapshot.isFromMe {
                Text("For you")
            } else if !snapshot.isHeard {
                Text("New")
            }
            Text(snapshot.createdAt, style: .relative)
        }
        .font(.caption)
        .foregroundStyle(secondaryText)
        .lineLimit(1)
    }

    private var onHomeScreen: Bool {
        switch family {
        case .systemSmall, .systemMedium, .systemLarge, .systemExtraLarge:
            return true
        default:
            return false
        }
    }

    private var primaryText: Color { onHomeScreen ? Theme.widgetCream : .primary }
    private var secondaryText: Color { onHomeScreen ? Theme.widgetMuted : .secondary }
    private var waveColor: Color { onHomeScreen ? Theme.widgetWave : .primary }

    @ViewBuilder
    private var background: some View {
        if onHomeScreen {
            Theme.widgetInk
        } else {
            AccessoryWidgetBackground()
        }
    }

    private var link: URL {
        if let id = snapshot?.noteID {
            return URL(string: "voicenotes://play/\(id.uuidString)") ?? URL(string: "voicenotes://inbox")!
        }
        return URL(string: "voicenotes://inbox")!
    }
}

struct VoiceNotesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.voicenotes.latest", provider: LatestNoteProvider()) { entry in
            LatestNoteWidgetView(snapshot: entry.snapshot)
        }
        .configurationDisplayName("Latest Note")
        .description("The newest voice note, with a photo and a waveform. Tap to play it.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

@main
struct VoiceNotesWidgetBundle: WidgetBundle {
    var body: some Widget {
        VoiceNotesWidget()
    }
}
