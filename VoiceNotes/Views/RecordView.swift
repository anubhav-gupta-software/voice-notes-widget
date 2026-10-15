import SwiftUI
import UIKit

struct RecordView: View {
    @Environment(NoteStore.self) private var store
    @State private var previewID = UUID()

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            PaperScreen {
                VStack(spacing: 20) {
                    targetPicker
                    Spacer(minLength: 8)
                    timeline
                    Spacer(minLength: 8)
                    controls
                    if let message = store.statusMessage {
                        StatusBanner(text: message)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .navigationTitle("Record")
            .toolbar { profileButton }
        }
        .onChange(of: store.recorder.finishedResult?.url) { _, _ in
            previewID = UUID()
        }
    }

    private var targetPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                targetChip(title: "Me", selected: store.recordTarget == .myself) {
                    store.recordTarget = .myself
                }
                ForEach(store.friends) { friend in
                    targetChip(
                        title: friend.displayName,
                        selected: store.recordTarget == .friend(friend.id)
                    ) {
                        store.recordTarget = .friend(friend.id)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .accessibilityLabel("Who is this note for")
    }

    private func targetChip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(selected ? Color.white : Theme.ink)
                .background(selected ? Theme.coral : Theme.card, in: Capsule())
                .overlay(Capsule().stroke(Theme.line, lineWidth: selected ? 0 : 1))
        }
        .buttonStyle(PressStyle())
    }

    private var timeline: some View {
        let samples = store.recorder.isRecording
            ? store.recorder.samples
            : (store.recorder.finishedResult?.samples ?? [])
        let elapsed = store.recorder.isRecording
            ? store.recorder.elapsed
            : (store.recorder.finishedResult?.duration ?? 0)
        let playing = store.player.noteID == previewID && store.recorder.finishedResult != nil

        return VStack(spacing: 18) {
            GeometryReader { geometry in
                WaveformView(
                    samples: samples,
                    progress: playing ? store.player.progress : 0,
                    active: Theme.coral,
                    inactive: Theme.amber.opacity(samples.isEmpty ? 0.25 : 0.9),
                    showsProgress: playing
                )
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0).onChanged { value in
                        guard let result = store.recorder.finishedResult else { return }
                        if store.player.noteID != previewID {
                            store.player.play(url: result.url, noteID: previewID)
                            store.player.pause()
                        }
                        let width = max(geometry.size.width, 1)
                        store.player.seek(to: value.location.x / width)
                    }
                )
            }
            .frame(height: 84)

            Text(NoteFormat.duration(playing ? store.player.currentTime : elapsed))
                .font(.system(size: 44, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(Theme.ink)
                .accessibilityLabel("Duration \(NoteFormat.duration(elapsed))")

            Text(caption)
                .font(.subheadline)
                .foregroundStyle(Theme.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var caption: String {
        if store.recorder.permissionDenied {
            return "The microphone is off for Voice Notes."
        }
        if store.recorder.isRecording {
            return "Up to \(Int(Theme.recordingLimit)) seconds"
        }
        if store.recorder.finishedResult != nil {
            return "Listen back, then send it."
        }
        return "A short note. Thirty seconds at most."
    }

    @ViewBuilder
    private var controls: some View {
        if store.recorder.permissionDenied {
            FillButton(title: "Open Settings", systemImage: "gearshape") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } else if store.recorder.isRecording {
            recordButton(system: "stop.fill", label: "Stop recording", recording: true) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                store.stopRecording()
            }
        } else if let result = store.recorder.finishedResult {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Button {
                        store.player.toggle(url: result.url, noteID: previewID)
                    } label: {
                        Image(systemName: store.player.noteID == previewID && store.player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .frame(width: 64, height: 64)
                            .background(Theme.card, in: Circle())
                            .overlay(Circle().stroke(Theme.line, lineWidth: 1))
                    }
                    .buttonStyle(PressStyle())
                    .accessibilityLabel(store.player.isPlaying ? "Pause preview" : "Play preview")

                    FillButton(title: "Send", systemImage: "paperplane.fill") {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        store.sendRecording()
                    }
                }
                Button("Retake") {
                    store.retake()
                }
                .font(.system(.body, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.secondary)
            }
        } else {
            recordButton(system: "mic.fill", label: "Start recording", recording: false) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                Task { await store.beginRecording() }
            }
        }
    }

    private func recordButton(system: String, label: String, recording: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(Theme.line, lineWidth: 6)
                    .frame(width: 116, height: 116)
                if recording {
                    Circle()
                        .trim(from: 0, to: min(1, store.recorder.elapsed / Theme.recordingLimit))
                        .stroke(Theme.coral, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 116, height: 116)
                }
                Circle()
                    .fill(Theme.coral)
                    .frame(width: 84, height: 84)
                Image(systemName: system)
                    .font(.title)
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(label)
    }

    private var profileButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                store.showProfile = true
            } label: {
                Image(systemName: "person.crop.circle")
                    .foregroundStyle(Theme.ink)
            }
            .accessibilityLabel("Profile")
        }
    }
}
