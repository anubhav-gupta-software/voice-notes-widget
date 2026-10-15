import PhotosUI
import SwiftUI
import UIKit

struct ProfileSheet: View {
    @Environment(NoteStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var copied = false
    @State private var serverURL = ""
    @State private var token = ""

    var body: some View {
        NavigationStack {
            PaperScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let profile = store.profile {
                            HStack(spacing: 16) {
                                PhotosPicker(selection: $photoItem, matching: .images) {
                                    AvatarView(name: name.isEmpty ? profile.displayName : name, photoJPEG: photoData, size: 84)
                                }
                                .buttonStyle(PressStyle())
                                VStack(alignment: .leading, spacing: 6) {
                                    TextField("Your name", text: $name)
                                        .font(.system(.title3, design: .rounded).weight(.semibold))
                                        .textInputAutocapitalization(.words)
                                    Text("Tap the photo to change it")
                                        .font(.caption)
                                        .foregroundStyle(Theme.secondary)
                                }
                            }

                            Card {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Your code")
                                        .font(.subheadline)
                                        .foregroundStyle(Theme.secondary)
                                    Text(profile.inviteCode)
                                        .font(.system(size: 28, weight: .semibold, design: .rounded).monospaced())
                                        .tracking(2)
                                    Button(copied ? "Copied" : "Copy code") {
                                        UIPasteboard.general.string = profile.inviteCode
                                        copied = true
                                    }
                                    .font(.system(.body, design: .rounded).weight(.semibold))
                                    .foregroundStyle(Theme.coral)
                                }
                            }

                            Card {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Home Screen widget")
                                        .font(.system(.headline, design: .rounded))
                                        .foregroundStyle(Theme.ink)
                                    Text(widgetStatus)
                                        .font(.subheadline)
                                        .foregroundStyle(Theme.secondary)
                                }
                            }

                            Card {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Sync server")
                                        .font(.system(.headline, design: .rounded))
                                        .foregroundStyle(Theme.ink)
                                    Text("Optional. Leave this blank to stay on the phone and on nearby Wi-Fi. A server carries a note when you are apart. No API key unless you set one.")
                                        .font(.subheadline)
                                        .foregroundStyle(Theme.secondary)
                                    TextField("http://192.168.1.20:8787", text: $serverURL)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                        .keyboardType(.URL)
                                        .padding(12)
                                        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    TextField("Token, if the server asks", text: $token)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                        .padding(12)
                                        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    Button(store.isSyncing ? "Syncing…" : "Save server") {
                                        store.updateSync(serverURL: serverURL, token: token)
                                    }
                                    .font(.system(.body, design: .rounded).weight(.semibold))
                                    .foregroundStyle(Theme.coral)
                                    .disabled(store.isSyncing)
                                    if let syncError = store.syncError {
                                        Text(syncError)
                                            .font(.footnote)
                                            .foregroundStyle(Theme.coral)
                                    }
                                }
                            }

                            FillButton(title: "Save", systemImage: "checkmark") {
                                store.updateSync(serverURL: serverURL, token: token)
                                store.updateProfile(name: name, photo: photoData)
                                dismiss()
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("You")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .onAppear {
            name = store.profile?.displayName ?? ""
            photoData = store.profile?.photoJPEG
            serverURL = store.syncSettings.serverURL
            token = store.syncSettings.token
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let picked = try? await item.loadTransferable(type: PickedPhoto.self) {
                    photoData = ImageThumb.jpeg(from: picked.data) ?? photoData
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var widgetStatus: String {
        if AppGroup.isAvailable {
            return "Sharing is on. The widget shows the newest note you haven't heard, or the newest one you kept for yourself."
        }
        return "The widget is installed, but this build can't share notes with it yet. Turn the App Group entitlement back on in Config/Shared.xcconfig, then record again."
    }
}
