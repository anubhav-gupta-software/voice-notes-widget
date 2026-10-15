import SwiftUI

struct InboxView: View {
    @Environment(NoteStore.self) private var store

    var body: some View {
        NavigationStack {
            PaperScreen {
                Group {
                    if store.inboxNotes.isEmpty {
                        empty
                    } else {
                        List {
                            if let message = store.statusMessage {
                                StatusBanner(text: message)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                            }
                            ForEach(store.inboxNotes) { note in
                                Button {
                                    store.open(note: note, autoplay: true)
                                } label: {
                                    InboxRow(note: note)
                                }
                                .buttonStyle(.plain)
                                .listRowBackground(Theme.card)
                                .listRowSeparator(.hidden)
                                .swipeActions {
                                    Button(role: .destructive) {
                                        store.deleteNote(note)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Inbox")
            .toolbar { profileButton }
        }
    }

    private var empty: some View {
        VStack(spacing: 16) {
            Spacer()
            WaveformView(
                samples: WidgetSnapshot.preview.waveform,
                active: Theme.amber,
                inactive: Theme.line
            )
            .frame(height: 48)
            .padding(.horizontal, 48)
            .accessibilityHidden(true)
            Text("Nothing waiting")
                .font(.system(.title2, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.ink)
            Text("Record a note for yourself to try the widget, or add a friend and leave one for them.")
                .font(.body)
                .foregroundStyle(Theme.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var profileButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                store.showProfile = true
            } label: {
                if let profile = store.profile {
                    AvatarView(name: profile.displayName, photoJPEG: profile.photoJPEG, size: 32)
                } else {
                    Image(systemName: "person.crop.circle")
                }
            }
            .accessibilityLabel("Profile")
        }
    }
}

private struct InboxRow: View {
    @Environment(NoteStore.self) private var store
    var note: VoiceNote

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                AvatarView(name: store.title(for: note), photoJPEG: store.photo(for: note), size: 52)
                if !note.isHeard {
                    Circle()
                        .fill(Theme.coral)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Theme.card, lineWidth: 2))
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(store.title(for: note))
                        .font(.system(.body, design: .rounded).weight(note.isHeard ? .regular : .semibold))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Text(note.createdAt, format: .relative(presentation: .named))
                        .font(.caption)
                        .foregroundStyle(Theme.secondary)
                }
                WaveformView(
                    samples: note.waveform,
                    active: note.isHeard ? Theme.secondary : Theme.amber,
                    inactive: note.isHeard ? Theme.line : Theme.amber.opacity(0.85)
                )
                .frame(height: 22)
                Text(NoteFormat.duration(note.duration))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.secondary)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(store.title(for: note)), \(NoteFormat.duration(note.duration))")
        .accessibilityHint(note.isHeard ? "Plays the note" : "Unheard. Plays the note")
    }
}
