import PhotosUI
import SwiftUI

struct OnboardingView: View {
    @Environment(NoteStore.self) private var store
    @State private var name = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @FocusState private var nameFocused: Bool

    var body: some View {
        PaperScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 10) {
                        WaveformView(
                            samples: WidgetSnapshot.preview.waveform,
                            active: Theme.coral,
                            inactive: Theme.amber
                        )
                        .frame(width: 120, height: 36)
                        .accessibilityHidden(true)

                        Text("Leave a voice note")
                            .font(.system(.largeTitle, design: .rounded).weight(.bold))
                            .foregroundStyle(Theme.ink)
                        Text("Record up to 30 seconds. The latest one from a friend sits on your Home Screen with their photo and a waveform.")
                            .font(.body)
                            .foregroundStyle(Theme.secondary)
                    }

                    VStack(spacing: 18) {
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            ZStack(alignment: .bottomTrailing) {
                                AvatarView(name: name.isEmpty ? "You" : name, photoJPEG: photoData, size: 96)
                                Image(systemName: "camera.fill")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(7)
                                    .background(Theme.ink, in: Circle())
                                    .offset(x: 4, y: 4)
                            }
                        }
                        .buttonStyle(PressStyle())
                        .accessibilityLabel("Add a photo")

                        TextField("Your name", text: $name)
                            .focused($nameFocused)
                            .textContentType(.name)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.done)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Theme.line, lineWidth: 1)
                            )
                    }
                    .frame(maxWidth: .infinity)

                    FillButton(title: "Create my code", systemImage: "arrow.right") {
                        store.createProfile(name: name, photo: photoData)
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
                }
                .padding(24)
            }
        }
        .onAppear { nameFocused = true }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    photoData = ImageThumb.jpeg(from: data) ?? data
                }
            }
        }
    }
}
