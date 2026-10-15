import Foundation

enum Disk {
    static var root: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("VoiceNotes", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static var audioDirectory: URL {
        let directory = root.appendingPathComponent("audio", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func audioURL(filename: String) -> URL {
        audioDirectory.appendingPathComponent(filename)
    }

    static func load<T: Decodable>(_ name: String, as type: T.Type) -> T? {
        let url = root.appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONCoding.decoder.decode(type, from: data)
    }

    static func save<T: Encodable>(_ value: T, name: String) {
        guard let data = try? JSONCoding.encoder.encode(value) else { return }
        let url = root.appendingPathComponent(name)
        try? data.write(to: url, options: .atomic)
    }

    static func removeAudio(filename: String) {
        try? FileManager.default.removeItem(at: audioURL(filename: filename))
    }
}
