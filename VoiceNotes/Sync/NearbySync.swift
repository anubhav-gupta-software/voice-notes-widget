import Foundation
import MultipeerConnectivity

struct DiscoveredFriend: Identifiable, Equatable {
    var code: String
    var name: String
    var id: String { code }
}

struct PeerProfile: Codable {
    var displayName: String
    var inviteCode: String
    var photoJPEG: Data?
}

struct PeerNoteMeta: Codable {
    var id: UUID
    var senderCode: String
    var senderName: String
    var recipientCode: String
    var createdAt: Date
    var duration: TimeInterval
    var waveform: [Float]
}

struct PeerEnvelope: Codable {
    var profile: PeerProfile?
    var note: PeerNoteMeta?
    var ack: UUID?
}

@MainActor
final class NearbySync: NSObject {
    private weak var store: NoteStore?
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var links: [Link] = []
    private var pendingMeta: [UUID: PeerNoteMeta] = [:]
    private var pendingAudio: [UUID: URL] = [:]
    private var inFlight: Set<UUID> = []
    private var lastInvite: [String: Date] = [:]

    private struct Link {
        var code: String
        var name: String
        var peer: MCPeerID
    }

    func attach(_ store: NoteStore) {
        self.store = store
    }

    func start() {
        guard session == nil, let store, let profile = store.profile, store.syncSettings.nearbyEnabled else { return }
        let displayName = Self.peerName(profile.displayName)
        let peerID = MCPeerID(displayName: displayName)
        let session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        let info = [
            "code": profile.inviteCode,
            "name": String(profile.displayName.prefix(28))
        ]
        let advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: info, serviceType: Self.serviceType)
        advertiser.delegate = self
        let browser = MCNearbyServiceBrowser(peer: peerID, serviceType: Self.serviceType)
        browser.delegate = self
        self.session = session
        self.advertiser = advertiser
        self.browser = browser
        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
    }

    func stop() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()
        advertiser = nil
        browser = nil
        session = nil
        links = []
        inFlight = []
        publish()
    }

    func restart() {
        stop()
        start()
    }

    func reconsider() {
        lastInvite = [:]
        for link in links {
            invite(link)
        }
        flush()
    }

    func flush() {
        guard let store, let session else { return }
        for note in store.pendingOutgoing() {
            guard !inFlight.contains(note.id),
                  let friendID = note.friendID,
                  let friend = store.friend(id: friendID),
                  let link = links.first(where: { $0.code == friend.inviteCode }),
                  session.connectedPeers.contains(link.peer) else { continue }
            send(note: note, to: link.peer)
        }
    }

    private func send(note: VoiceNote, to peer: MCPeerID) {
        guard let store, let profile = store.profile, let session, let friendID = note.friendID, let friend = store.friend(id: friendID) else { return }
        let meta = PeerNoteMeta(
            id: note.id,
            senderCode: profile.inviteCode,
            senderName: profile.displayName,
            recipientCode: friend.inviteCode,
            createdAt: note.createdAt,
            duration: note.duration,
            waveform: note.waveform
        )
        guard let data = try? JSONCoding.encoder.encode(PeerEnvelope(profile: nil, note: meta, ack: nil)) else { return }
        do {
            try session.send(data, toPeers: [peer], with: .reliable)
        } catch {
            return
        }
        let url = Disk.audioURL(filename: note.audioFilename)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        inFlight.insert(note.id)
        session.sendResource(at: url, withName: "note-\(note.id.uuidString).m4a", toPeer: peer) { [weak self] error in
            guard error != nil else { return }
            Task { @MainActor in
                self?.inFlight.remove(note.id)
            }
        }
    }

    private func sendProfile(to peer: MCPeerID) {
        guard let profile = store?.profile else { return }
        let payload = PeerProfile(displayName: profile.displayName, inviteCode: profile.inviteCode, photoJPEG: profile.photoJPEG)
        send(PeerEnvelope(profile: payload, note: nil, ack: nil), to: peer)
    }

    private func send(_ envelope: PeerEnvelope, to peer: MCPeerID) {
        guard let session, session.connectedPeers.contains(peer), let data = try? JSONCoding.encoder.encode(envelope) else { return }
        try? session.send(data, toPeers: [peer], with: .reliable)
    }

    private func invite(_ link: Link) {
        guard let session, let store, store.shouldInvite(remoteCode: link.code) else { return }
        if session.connectedPeers.contains(link.peer) { return }
        if let last = lastInvite[link.code], Date().timeIntervalSince(last) < 12 { return }
        lastInvite[link.code] = Date()
        let context = store.profile?.inviteCode.data(using: .utf8)
        browser?.invitePeer(link.peer, to: session, withContext: context, timeout: 25)
    }

    private func remember(code: String, name: String?, peer: MCPeerID) {
        let cleaned = InviteCode.normalize(code)
        guard cleaned.count == InviteCode.length else { return }
        if let index = links.firstIndex(where: { $0.peer == peer || $0.code == cleaned }) {
            links[index].code = cleaned
            links[index].peer = peer
            if let name, !name.isEmpty {
                links[index].name = name
            }
        } else {
            let displayName = (name?.isEmpty == false) ? (name ?? "Friend \(cleaned)") : "Friend \(cleaned)"
            links.append(Link(code: cleaned, name: displayName, peer: peer))
        }
        publish()
    }

    private func forget(peer: MCPeerID) {
        links.removeAll { $0.peer == peer }
        publish()
    }

    private func publish() {
        guard let store else { return }
        let connected = session?.connectedPeers ?? []
        store.nearbyCodes = Set(links.filter { link in connected.contains(link.peer) }.map(\.code))
        store.nearbyPeople = links
            .filter { link in !store.friends.contains { $0.inviteCode == link.code } }
            .map { DiscoveredFriend(code: $0.code, name: $0.name) }
    }

    private func handleState(_ state: MCSessionState, peer: MCPeerID) {
        switch state {
        case .connected:
            sendProfile(to: peer)
            flush()
            publish()
        case .notConnected:
            inFlight = []
            forget(peer: peer)
        default:
            break
        }
    }

    private func handle(data: Data, from peer: MCPeerID) {
        guard let envelope = try? JSONCoding.decoder.decode(PeerEnvelope.self, from: data) else { return }
        if let profile = envelope.profile {
            remember(code: profile.inviteCode, name: profile.displayName, peer: peer)
            store?.learnPeer(profile)
            flush()
        }
        if let note = envelope.note {
            remember(code: note.senderCode, name: note.senderName, peer: peer)
            pendingMeta[note.id] = note
            finish(note.id)
        }
        if let ack = envelope.ack {
            inFlight.remove(ack)
            store?.markDelivered(noteID: ack)
        }
    }

    private func receiveAudio(named resourceName: String, url: URL) {
        guard let id = Self.noteID(from: resourceName) else { return }
        pendingAudio[id] = url
        finish(id)
    }

    private func finish(_ id: UUID) {
        guard let meta = pendingMeta[id], let url = pendingAudio[id] else { return }
        pendingMeta[id] = nil
        pendingAudio[id] = nil
        let saved = store?.importIncoming(meta: meta, audioURL: url) ?? false
        if saved {
            guard let session else { return }
            for peer in session.connectedPeers {
                send(PeerEnvelope(profile: nil, note: nil, ack: id), to: peer)
            }
        }
    }

    private func handleInvitation(from peer: MCPeerID, context: Data?) -> Bool {
        let code = context.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        if !code.isEmpty {
            remember(code: code, name: nil, peer: peer)
        }
        if code.isEmpty {
            return store?.isPairing == true
        }
        return store?.shouldAccept(remoteCode: code) ?? false
    }

    private static func noteID(from resourceName: String) -> UUID? {
        var stem = resourceName
        if stem.hasPrefix("note-") {
            stem.removeFirst("note-".count)
        }
        if stem.hasSuffix(".m4a") {
            stem.removeLast(".m4a".count)
        }
        return UUID(uuidString: stem)
    }

    private static func peerName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.isEmpty ? "Voice Notes" : trimmed
        return String(base.prefix(40))
    }

    private static let serviceType = "voicenote"
}

extension NearbySync: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            self.handleState(state, peer: peerID)
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        Task { @MainActor in
            self.handle(data: data, from: peerID)
        }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}

    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}

    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        guard error == nil, let localURL else { return }
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("incoming-\(UUID().uuidString)-\(resourceName)")
        do {
            try FileManager.default.copyItem(at: localURL, to: destination)
        } catch {
            return
        }
        let name = resourceName
        Task { @MainActor in
            self.receiveAudio(named: name, url: destination)
        }
    }
}

extension NearbySync: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        Task { @MainActor in
            let accept = self.handleInvitation(from: peerID, context: context)
            invitationHandler(accept, accept ? self.session : nil)
        }
    }

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        Task { @MainActor in
            self.store?.syncError = "Nearby couldn't start. Allow Local Network for Voice Notes in Settings."
        }
    }
}

extension NearbySync: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        Task { @MainActor in
            guard let code = info?["code"] else { return }
            self.remember(code: code, name: info?["name"], peer: peerID)
            if let link = self.links.first(where: { $0.code == InviteCode.normalize(code) }) {
                self.invite(link)
            }
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in
            self.forget(peer: peerID)
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        Task { @MainActor in
            self.store?.syncError = "Nearby couldn't start. Allow Local Network for Voice Notes in Settings."
        }
    }
}
