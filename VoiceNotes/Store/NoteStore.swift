import Foundation
import WidgetKit

enum AppTab: Hashable {
    case inbox
    case record
    case friends
}

enum RecordTarget: Hashable {
    case myself
    case friend(UUID)
}

struct PlayerRoute: Identifiable, Equatable {
    var noteID: UUID
    var autoplay: Bool
    var id: UUID { noteID }
}

enum StoreError: LocalizedError {
    case invalidCode
    case ownCode
    case duplicateFriend
    case missingProfile

    var errorDescription: String? {
        switch self {
        case .invalidCode:
            return "Codes are 6 letters and numbers."
        case .ownCode:
            return "That's your own code."
        case .duplicateFriend:
            return "You already added that code."
        case .missingProfile:
            return "Set up your profile first."
        }
    }
}

@MainActor
@Observable
final class NoteStore {
    var profile: Profile?
    var friends: [Friend] = []
    var notes: [VoiceNote] = []
    var syncSettings = SyncSettings.empty
    var tab: AppTab = .inbox
    var recordTarget: RecordTarget = .myself
    var playerRoute: PlayerRoute?
    var showProfile = false
    var statusMessage: String?
    var syncError: String?
    var isSyncing = false
    var isPairing = false
    var nearbyCodes: Set<String> = []
    var nearbyPeople: [DiscoveredFriend] = []

    let recorder = VoiceRecorder()
    let player = NotePlayer()
    private let nearby = NearbySync()
    private var pairingTask: Task<Void, Never>?

    private var servicesStarted = false

    init(loadingFromDisk: Bool = true) {
        if loadingFromDisk {
            load()
        }
    }

    var inboxNotes: [VoiceNote] {
        notes
            .filter { $0.direction == .received || $0.direction == .toSelf }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var unheardCount: Int {
        inboxNotes.filter { !$0.isHeard }.count
    }

    func friend(id: UUID) -> Friend? {
        friends.first { $0.id == id }
    }

    func title(for note: VoiceNote) -> String {
        if note.direction == .toSelf {
            return "You"
        }
        if let id = note.friendID, let friend = friend(id: id) {
            return friend.displayName
        }
        return "Friend"
    }

    func photo(for note: VoiceNote) -> Data? {
        if note.direction == .toSelf {
            return profile?.photoJPEG
        }
        if let id = note.friendID {
            return friend(id: id)?.photoJPEG
        }
        return nil
    }

    func waitingCount(for friend: Friend) -> Int {
        notes.filter { $0.friendID == friend.id && $0.direction == .sent && $0.delivery == .waiting }.count
    }

    func notes(with friend: Friend) -> [VoiceNote] {
        notes
            .filter { $0.friendID == friend.id }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func startServices() {
        guard !servicesStarted else { return }
        servicesStarted = true
        nearby.attach(self)
        if syncSettings.nearbyEnabled {
            nearby.start()
        }
        refreshWidget()
    }

    func createProfile(name: String, photo: Data?) {
        let trimmed = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(24))
        guard !trimmed.isEmpty else { return }
        profile = Profile(
            id: UUID(),
            displayName: trimmed,
            inviteCode: InviteCode.make(),
            photoJPEG: photo.flatMap { ImageThumb.jpeg(from: $0) },
            createdAt: Date()
        )
        save()
        refreshWidget()
        if servicesStarted {
            nearby.start()
        }
    }

    func updateProfile(name: String, photo: Data?) {
        guard var profile else { return }
        let trimmed = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(24))
        guard !trimmed.isEmpty else { return }
        profile.displayName = trimmed
        profile.photoJPEG = photo.flatMap { ImageThumb.jpeg(from: $0) }
        self.profile = profile
        save()
        refreshWidget()
        nearby.restart()
        flash("Profile saved.")
    }

    func addFriend(code raw: String) throws {
        guard profile != nil else { throw StoreError.missingProfile }
        let code = InviteCode.normalize(raw)
        guard code.count == InviteCode.length else { throw StoreError.invalidCode }
        if code == profile?.inviteCode { throw StoreError.ownCode }
        if friends.contains(where: { $0.inviteCode == code }) { throw StoreError.duplicateFriend }
        friends.append(Friend(
            id: UUID(),
            displayName: "Friend \(code)",
            inviteCode: code,
            photoJPEG: nil,
            addedAt: Date(),
            lastSeenAt: nil,
            hasCustomName: false
        ))
        friends.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        save()
        nearby.reconsider()
        flash("Added \(code). Notes you record will send when you're nearby, or through a sync server.")
    }

    func renameFriend(_ friend: Friend, to name: String) {
        let trimmed = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(24))
        guard !trimmed.isEmpty, let index = friends.firstIndex(where: { $0.id == friend.id }) else { return }
        var updated = friends
        updated[index].displayName = trimmed
        updated[index].hasCustomName = true
        friends = updated
        save()
        refreshWidget()
    }

    func removeFriend(_ friend: Friend) {
        let related = notes.filter { $0.friendID == friend.id }
        for note in related {
            Disk.removeAudio(filename: note.audioFilename)
        }
        notes.removeAll { $0.friendID == friend.id }
        friends.removeAll { $0.id == friend.id }
        save()
        refreshWidget()
    }

    func deleteNote(_ note: VoiceNote) {
        Disk.removeAudio(filename: note.audioFilename)
        notes.removeAll { $0.id == note.id }
        if player.noteID == note.id {
            player.stop()
        }
        if playerRoute?.noteID == note.id {
            playerRoute = nil
        }
        save()
        refreshWidget()
    }

    func beginRecording() async {
        player.stop()
        let started = await recorder.start()
        if !started, let failure = recorder.failure {
            flash(failure)
        }
    }

    func stopRecording() {
        recorder.stop()
    }

    func retake() {
        player.stop()
        recorder.discard()
    }

    func sendRecording() {
        guard let result = recorder.finishedResult, profile != nil else { return }
        guard result.duration >= 0.4 else {
            recorder.discard()
            flash("Hold on a little longer. That one was too short.")
            return
        }

        let waveform = WaveformExtractor.peaks(url: result.url, fallback: result.samples)
        let friendForSend: Friend?
        switch recordTarget {
        case .myself:
            friendForSend = nil
        case .friend(let friendID):
            guard let friend = friend(id: friendID) else {
                flash("Pick a friend first.")
                return
            }
            friendForSend = friend
        }

        let id = UUID()
        let filename = "\(id.uuidString).m4a"
        let destination = Disk.audioURL(filename: filename)
        do {
            try FileManager.default.moveItem(at: result.url, to: destination)
        } catch {
            flash("I couldn't save that recording.")
            return
        }
        recorder.reset()
        player.stop()

        if let friendForSend {
            notes.append(VoiceNote(
                id: id,
                direction: .sent,
                friendID: friendForSend.id,
                createdAt: Date(),
                duration: result.duration,
                audioFilename: filename,
                waveform: waveform,
                isHeard: true,
                delivery: .waiting,
                uploaded: false
            ))
            flash("Saved for \(friendForSend.displayName). It sends when you're on the same Wi-Fi, or through a sync server.")
        } else {
            notes.append(VoiceNote(
                id: id,
                direction: .toSelf,
                friendID: nil,
                createdAt: Date(),
                duration: result.duration,
                audioFilename: filename,
                waveform: waveform,
                isHeard: false,
                delivery: .local,
                uploaded: true
            ))
            flash("Saved. It's in your inbox, and on the widget when sharing is on.")
        }

        save()
        refreshWidget()
        nearby.flush()
    }

    func open(note: VoiceNote, autoplay: Bool) {
        playerRoute = PlayerRoute(noteID: note.id, autoplay: autoplay)
    }

    func play(noteID: UUID) {
        guard let note = notes.first(where: { $0.id == noteID }) else { return }
        let url = Disk.audioURL(filename: note.audioFilename)
        guard FileManager.default.fileExists(atPath: url.path) else {
            flash("That recording is missing.")
            return
        }
        player.play(url: url, noteID: noteID)
        markHeard(noteID: noteID)
    }

    func markHeard(noteID: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == noteID }) else { return }
        guard !notes[index].isHeard else { return }
        var updated = notes
        updated[index].isHeard = true
        notes = updated
        save()
        refreshWidget()
    }

    func handleOpenURL(_ url: URL) {
        guard url.scheme == "voicenotes" else { return }
        if url.host == "play" {
            let raw = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard let id = UUID(uuidString: raw), notes.contains(where: { $0.id == id }) else { return }
            tab = .inbox
            playerRoute = PlayerRoute(noteID: id, autoplay: true)
        } else {
            tab = .inbox
        }
    }

    func flash(_ text: String) {
        statusMessage = text
        Task {
            try? await Task.sleep(for: .seconds(3.6))
            if statusMessage == text {
                statusMessage = nil
            }
        }
    }

    func refreshWidget() {
        let payload = WidgetPayload(featured: featuredSnapshot(), updatedAt: Date())
        AppGroup.write(payload)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func featuredSnapshot() -> WidgetSnapshot? {
        let pool = notes.filter { $0.direction != .sent }
        let unheard = pool.filter { !$0.isHeard }.sorted { $0.createdAt > $1.createdAt }
        guard let note = unheard.first ?? pool.sorted(by: { $0.createdAt > $1.createdAt }).first else {
            return nil
        }
        let fromMe = note.direction == .toSelf
        let name = fromMe ? (profile?.displayName ?? "You") : title(for: note)
        return WidgetSnapshot(
            noteID: note.id,
            friendName: name,
            initials: NoteFormat.initials(name),
            photoJPEG: photo(for: note),
            duration: note.duration,
            createdAt: note.createdAt,
            waveform: note.waveform,
            isHeard: note.isHeard,
            isFromMe: fromMe
        )
    }

    private func load() {
        profile = Disk.load("profile.json", as: Profile.self)
        friends = Disk.load("friends.json", as: [Friend].self) ?? []
        notes = Disk.load("notes.json", as: [VoiceNote].self) ?? []
        syncSettings = Disk.load("sync.json", as: SyncSettings.self) ?? .empty
    }

    func save() {
        if let profile {
            Disk.save(profile, name: "profile.json")
        }
        Disk.save(friends, name: "friends.json")
        Disk.save(notes, name: "notes.json")
        Disk.save(syncSettings, name: "sync.json")
    }

    func setNearbyEnabled(_ enabled: Bool) {
        syncSettings.nearbyEnabled = enabled
        save()
        if enabled {
            nearby.start()
        } else {
            stopPairing()
            nearby.stop()
        }
    }

    func startPairing() {
        guard profile != nil else { return }
        isPairing = true
        syncError = nil
        if !syncSettings.nearbyEnabled {
            setNearbyEnabled(true)
        } else {
            nearby.start()
        }
        nearby.reconsider()
        pairingTask?.cancel()
        pairingTask = Task {
            try? await Task.sleep(for: .seconds(90))
            if !Task.isCancelled {
                stopPairing()
            }
        }
    }

    func stopPairing() {
        pairingTask?.cancel()
        pairingTask = nil
        isPairing = false
    }

    func shouldInvite(remoteCode: String) -> Bool {
        guard let mine = profile?.inviteCode, remoteCode != mine else { return false }
        let known = friends.contains { $0.inviteCode == remoteCode } || isPairing
        return known && mine < remoteCode
    }

    func shouldAccept(remoteCode: String) -> Bool {
        guard let mine = profile?.inviteCode, remoteCode != mine else { return false }
        let known = friends.contains { $0.inviteCode == remoteCode } || isPairing
        return known && mine > remoteCode
    }

    func pendingOutgoing() -> [VoiceNote] {
        notes.filter { $0.direction == .sent && $0.delivery == .waiting }
    }

    func learnPeer(_ remote: PeerProfile) {
        upsertFriend(code: remote.inviteCode, name: remote.displayName, photo: remote.photoJPEG, seen: true)
    }

    func applyDiscoveredName(code: String, name: String) {
        let cleaned = InviteCode.normalize(code)
        guard let index = friends.firstIndex(where: { $0.inviteCode == cleaned }), !friends[index].hasCustomName else { return }
        guard !name.isEmpty, name != "Friend \(cleaned)" else { return }
        var updated = friends
        updated[index].displayName = name
        friends = updated
        save()
    }

    @discardableResult
    func importIncoming(meta: PeerNoteMeta, audioURL: URL) -> Bool {
        guard let profile else { return false }
        guard meta.recipientCode == profile.inviteCode else { return false }
        upsertFriend(code: meta.senderCode, name: meta.senderName, photo: nil, seen: true)
        if notes.contains(where: { $0.id == meta.id }) {
            return true
        }
        let filename = "\(meta.id.uuidString).m4a"
        let destination = Disk.audioURL(filename: filename)
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: audioURL, to: destination)
        } catch {
            return false
        }
        let friendID = friends.first { $0.inviteCode == meta.senderCode }?.id
        notes.append(VoiceNote(
            id: meta.id,
            direction: .received,
            friendID: friendID,
            createdAt: meta.createdAt,
            duration: meta.duration,
            audioFilename: filename,
            waveform: meta.waveform,
            isHeard: false,
            delivery: .delivered,
            uploaded: true
        ))
        save()
        refreshWidget()
        let sender = friends.first { $0.inviteCode == meta.senderCode }?.displayName ?? meta.senderName
        flash("New note from \(sender).")
        return true
    }

    func markDelivered(noteID: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == noteID }) else { return }
        guard notes[index].delivery != .delivered else { return }
        var updated = notes
        updated[index].delivery = .delivered
        notes = updated
        save()
    }

    private func upsertFriend(code: String, name: String, photo: Data?, seen: Bool) {
        let cleaned = InviteCode.normalize(code)
        guard cleaned.count == InviteCode.length, cleaned != profile?.inviteCode else { return }
        if let index = friends.firstIndex(where: { $0.inviteCode == cleaned }) {
            var updated = friends
            if !updated[index].hasCustomName, !name.isEmpty {
                updated[index].displayName = name
            }
            if let photo {
                updated[index].photoJPEG = photo
            }
            if seen {
                updated[index].lastSeenAt = Date()
            }
            friends = updated
        } else {
            friends.append(Friend(
                id: UUID(),
                displayName: name.isEmpty ? "Friend \(cleaned)" : name,
                inviteCode: cleaned,
                photoJPEG: photo,
                addedAt: Date(),
                lastSeenAt: seen ? Date() : nil,
                hasCustomName: false
            ))
        }
        save()
        refreshWidget()
    }
}
