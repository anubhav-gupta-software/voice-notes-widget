import Foundation

struct RemoteNote: Codable {
    var id: UUID
    var senderCode: String
    var senderName: String
    var senderPhotoBase64: String?
    var recipientCode: String
    var createdAt: TimeInterval
    var duration: TimeInterval
    var waveform: [Float]
    var audioBase64: String
}

private struct RemoteNotesResponse: Codable {
    var notes: [RemoteNote]
}

enum RemoteSyncError: LocalizedError {
    case badURL
    case server(Int)

    var errorDescription: String? {
        switch self {
        case .badURL:
            return "That sync server address doesn't look right."
        case .server(let code):
            return "The sync server replied \(code)."
        }
    }
}

enum RemoteSync {
    static func push(note: RemoteNote, settings: SyncSettings) async throws {
        let url = try endpoint(settings, path: "v1/notes")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        authorize(&request, token: settings.token)
        request.httpBody = try JSONEncoder().encode(note)
        let (_, response) = try await URLSession.shared.data(for: request)
        try validate(response)
    }

    static func pull(recipientCode: String, since: TimeInterval, settings: SyncSettings) async throws -> [RemoteNote] {
        var url = try endpoint(settings, path: "v1/notes")
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw RemoteSyncError.badURL
        }
        components.queryItems = [
            URLQueryItem(name: "recipient", value: recipientCode),
            URLQueryItem(name: "since", value: String(since))
        ]
        guard let queried = components.url else { throw RemoteSyncError.badURL }
        url = queried
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        authorize(&request, token: settings.token)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)
        return try JSONDecoder().decode(RemoteNotesResponse.self, from: data).notes
    }

    private static func authorize(_ request: inout URLRequest, token: String) {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        request.setValue("Bearer \(trimmed)", forHTTPHeaderField: "Authorization")
    }

    private static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            throw RemoteSyncError.server(http.statusCode)
        }
    }

    private static func endpoint(_ settings: SyncSettings, path: String) throws -> URL {
        var raw = settings.serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { throw RemoteSyncError.badURL }
        if !raw.contains("://") {
            raw = "http://" + raw
        }
        guard var components = URLComponents(string: raw), components.host != nil else {
            throw RemoteSyncError.badURL
        }
        let base = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let extra = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let pieces = [base, extra].filter { !$0.isEmpty }
        components.path = "/" + pieces.joined(separator: "/")
        components.query = nil
        components.fragment = nil
        guard let url = components.url else { throw RemoteSyncError.badURL }
        return url
    }
}
