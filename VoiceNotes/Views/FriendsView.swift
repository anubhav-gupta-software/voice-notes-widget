import SwiftUI
import UIKit

struct FriendsView: View {
    @Environment(NoteStore.self) private var store
    @State private var code = ""
    @State private var entryError: String?
    @State private var friendToRemove: Friend?

    var body: some View {
        NavigationStack {
            PaperScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let profile = store.profile {
                            codeCard(profile)
                        }
                        addCard
                        if store.friends.isEmpty {
                            Text("Friends you add show up here. A note waits on this phone until you are on the same Wi-Fi, or until you point both phones at a sync server.")
                                .font(.subheadline)
                                .foregroundStyle(Theme.secondary)
                                .padding(.horizontal, 4)
                        } else {
                            ForEach(store.friends) { friend in
                                NavigationLink {
                                    FriendDetailView(friendID: friend.id)
                                } label: {
                                    friendRow(friend)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Friends")
            .toolbar { profileButton }
            .confirmationDialog(
                "Remove this friend?",
                isPresented: Binding(
                    get: { friendToRemove != nil },
                    set: { if !$0 { friendToRemove = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Remove", role: .destructive) {
                    if let friendToRemove {
                        store.removeFriend(friendToRemove)
                    }
                    friendToRemove = nil
                }
                Button("Cancel", role: .cancel) {
                    friendToRemove = nil
                }
            } message: {
                Text("Their notes on this phone are deleted too.")
            }
        }
    }

    private func codeCard(_ profile: Profile) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text("Your code")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondary)
                Text(profile.inviteCode)
                    .font(.system(size: 32, weight: .semibold, design: .rounded).monospaced())
                    .tracking(3)
                    .foregroundStyle(Theme.ink)
                HStack(spacing: 16) {
                    Button {
                        UIPasteboard.general.string = profile.inviteCode
                        store.flash("Copied \(profile.inviteCode).")
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    ShareLink(item: "Add me in Voice Notes. My code is \(profile.inviteCode).") {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.coral)
                .padding(.top, 4)
            }
        }
    }

    private var addCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Add with a code")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(Theme.ink)
                HStack(spacing: 8) {
                    TextField("6 characters", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .rounded).monospaced())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    Button("Add") {
                        submitCode()
                    }
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Theme.ink, in: Capsule())
                }
                if let entryError {
                    Text(entryError)
                        .font(.footnote)
                        .foregroundStyle(Theme.coral)
                }
            }
        }
    }

    private func friendRow(_ friend: Friend) -> some View {
        Card {
            HStack(spacing: 12) {
                AvatarView(name: friend.displayName, photoJPEG: friend.photoJPEG, size: 48)
                VStack(alignment: .leading, spacing: 4) {
                    Text(friend.displayName)
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Text(friendSubtitle(friend))
                        .font(.caption)
                        .foregroundStyle(Theme.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.secondary)
            }
        }
        .contextMenu {
            Button("Remove", role: .destructive) {
                friendToRemove = friend
            }
        }
    }

    private func friendSubtitle(_ friend: Friend) -> String {
        let waiting = store.waitingCount(for: friend)
        if waiting == 1 { return "1 note waiting to send" }
        if waiting > 1 { return "\(waiting) notes waiting to send" }
        return friend.inviteCode
    }

    private func submitCode() {
        do {
            try store.addFriend(code: code)
            code = ""
            entryError = nil
        } catch {
            entryError = error.localizedDescription
        }
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

struct FriendDetailView: View {
    @Environment(NoteStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var friendID: UUID
    @State private var nickname = ""
    @State private var confirmRemove = false

    private var friend: Friend? {
        store.friend(id: friendID)
    }

    var body: some View {
        PaperScreen {
            if let friend {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 14) {
                            AvatarView(name: friend.displayName, photoJPEG: friend.photoJPEG, size: 72)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(friend.displayName)
                                    .font(.system(.title2, design: .rounded).weight(.semibold))
                                    .foregroundStyle(Theme.ink)
                                Text(friend.inviteCode)
                                    .font(.system(.body, design: .rounded).monospaced())
                                    .foregroundStyle(Theme.secondary)
                            }
                        }

                        Card {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Name on this phone")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.secondary)
                                TextField("Name", text: $nickname)
                                    .textInputAutocapitalization(.words)
                                Button("Save name") {
                                    store.renameFriend(friend, to: nickname)
                                }
                                .font(.system(.body, design: .rounded).weight(.semibold))
                                .foregroundStyle(Theme.coral)
                            }
                        }

                        let exchanged = store.notes(with: friend)
                        if exchanged.isEmpty {
                            Text("No notes with \(friend.displayName) yet.")
                                .foregroundStyle(Theme.secondary)
                        } else {
                            ForEach(exchanged) { note in
                                Button {
                                    store.open(note: note, autoplay: true)
                                } label: {
                                    HStack {
                                        Image(systemName: note.direction == .sent ? "arrow.up.right" : "arrow.down.left")
                                            .foregroundStyle(note.direction == .sent ? Theme.moss : Theme.coral)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(note.direction == .sent ? "You sent" : "They sent")
                                                .foregroundStyle(Theme.ink)
                                            Text(detailSubtitle(note))
                                                .font(.caption)
                                                .foregroundStyle(Theme.secondary)
                                        }
                                        Spacer()
                                        Text(NoteFormat.duration(note.duration))
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(Theme.secondary)
                                    }
                                    .padding(14)
                                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Button("Remove friend", role: .destructive) {
                            confirmRemove = true
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                    }
                    .padding(20)
                }
                .onAppear { nickname = friend.displayName }
                .navigationTitle(friend.displayName)
                .navigationBarTitleDisplayMode(.inline)
                .confirmationDialog("Remove \(friend.displayName)?", isPresented: $confirmRemove, titleVisibility: .visible) {
                    Button("Remove", role: .destructive) {
                        store.removeFriend(friend)
                        dismiss()
                    }
                }
            } else {
                Text("That friend is gone.")
                    .foregroundStyle(Theme.secondary)
            }
        }
    }

    private func detailSubtitle(_ note: VoiceNote) -> String {
        let when = note.createdAt.formatted(.relative(presentation: .named))
        if note.direction == .sent && note.delivery == .waiting {
            return "\(when) · waiting to send"
        }
        if note.direction == .sent && note.delivery == .delivered {
            return "\(when) · delivered"
        }
        return when
    }
}
