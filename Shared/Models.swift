import Foundation

struct Profile: Codable, Equatable, Identifiable {
    var id: UUID
    var displayName: String
    var inviteCode: String
    var photoJPEG: Data?
    var createdAt: Date
}

struct Friend: Codable, Equatable, Identifiable {
    var id: UUID
    var displayName: String
    var inviteCode: String
    var photoJPEG: Data?
    var addedAt: Date
    var lastSeenAt: Date?
    var hasCustomName: Bool
}

enum NoteDirection: String, Codable {
    case received
    case sent
    case toSelf
}

enum DeliveryState: String, Codable {
    case local
    case waiting
    case delivered
}

struct VoiceNote: Codable, Equatable, Identifiable {
    var id: UUID
    var direction: NoteDirection
    var friendID: UUID?
    var createdAt: Date
    var duration: TimeInterval
    var audioFilename: String
    var waveform: [Float]
    var isHeard: Bool
    var delivery: DeliveryState
    var uploaded: Bool
}

struct SyncSettings: Codable, Equatable {
    var serverURL: String
    var token: String
    var nearbyEnabled: Bool

    static let empty = SyncSettings(serverURL: "", token: "", nearbyEnabled: true)
}

struct WidgetSnapshot: Codable, Equatable, Identifiable {
    var noteID: UUID
    var friendName: String
    var initials: String
    var photoJPEG: Data?
    var duration: TimeInterval
    var createdAt: Date
    var waveform: [Float]
    var isHeard: Bool
    var isFromMe: Bool

    var id: UUID { noteID }

    static let preview: WidgetSnapshot = {
        let samples = (0..<42).map { index -> Float in
            let x = Float(index) / 41
            let shape = abs(sin(x * .pi * 3.2)) * (0.28 + 0.72 * sin(x * .pi))
            return min(1, max(0.08, shape))
        }
        return WidgetSnapshot(
            noteID: UUID(uuidString: "E4B3C2A1-9F80-4D11-8A76-1234567890AB")!,
            friendName: "Maya",
            initials: "M",
            photoJPEG: nil,
            duration: 12,
            createdAt: Date(timeIntervalSince1970: 1_760_000_000),
            waveform: samples,
            isHeard: false,
            isFromMe: false
        )
    }()
}

struct WidgetPayload: Codable, Equatable {
    var featured: WidgetSnapshot?
    var updatedAt: Date
}

enum InviteCode {
    static let length = 6
    private static let alphabet: [Character] = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    static func make() -> String {
        String((0..<length).map { _ in alphabet[Int.random(in: 0..<alphabet.count)] })
    }

    static func normalize(_ raw: String) -> String {
        let allowed = Set(alphabet)
        return String(raw.uppercased().filter { allowed.contains($0) })
    }
}
