import SwiftUI

struct PlayerSheet: View {
    @Environment(NoteStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var route: PlayerRoute

    private var note: VoiceNote? {
        store.notes.first { $0.id == route.noteID }
    }

    var body: some View {
        PaperScreen {
            if let note {
                VStack(spacing: 22) {
                    Capsule()
                        .fill(Theme.line)
                        .frame(width: 36, height: 5)
                        .padding(.top, 8)

                    AvatarView(name: store.title(for: note), photoJPEG: store.photo(for: note), size: 96)

                    VStack(spacing: 4) {
                        Text(store.title(for: note))
                            .font(.system(.title2, design: .rounded).weight(.semibold))
                            .foregroundStyle(Theme.ink)
                        Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondary)
                    }

                    GeometryReader { geometry in
                        WaveformView(
                            samples: note.waveform,
                            progress: store.player.noteID == note.id ? store.player.progress : 0,
                            active: Theme.coral,
                            inactive: Theme.amber,
                            showsProgress: store.player.noteID == note.id
                        )
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let width = max(geometry.size.width, 1)
                                    store.player.seek(to: value.location.x / width)
                                }
                        )
                    }
                    .frame(height: 72)
                    .padding(.horizontal, 8)

                    HStack {
                        Text(NoteFormat.duration(store.player.noteID == note.id ? store.player.currentTime : 0))
                        Spacer()
                        Text(NoteFormat.duration(note.duration))
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.secondary)

                    Button {
                        if store.player.noteID == note.id && store.player.isPlaying {
                            store.player.pause()
                        } else {
                            store.play(noteID: note.id)
                        }
                    } label: {
                        Image(systemName: store.player.noteID == note.id && store.player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 76, height: 76)
                            .background(Theme.coral, in: Circle())
                    }
                    .buttonStyle(PressStyle())
                    .accessibilityLabel(store.player.noteID == note.id && store.player.isPlaying ? "Pause" : "Play")

                    Button("Done") { dismiss() }
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundStyle(Theme.secondary)
                    Spacer()
                }
                .padding(.horizontal, 24) 
            } else {
                Text("That note is gone.")
                    .foregroundStyle(Theme.secondary)
            }
        }
        .task(id: route.noteID) {
            if route.autoplay {
                store.play(noteID: route.noteID)
            }
        }
        .onDisappear {
            store.player.stop()
        }
    }
}
