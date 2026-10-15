import Foundation

/// Shared container for the latest note the Home Screen widget draws.
/// `containerURL` is nil until the App Group entitlement is in the
/// provisioning profile, so the app still runs if signing has to drop it.
enum AppGroup {
    static let identifier = "group.software.anubhavgupta.voicenotes"
    static let payloadFilename = "widget-payload.json"

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    static var isAvailable: Bool {
        containerURL != nil
    }

    static func readPayload() -> WidgetPayload? {
        guard let url = payloadURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONCoding.decoder.decode(WidgetPayload.self, from: data)
    }

    static func write(_ payload: WidgetPayload) {
        guard let url = payloadURL, let data = try? JSONCoding.encoder.encode(payload) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private static var payloadURL: URL? {
        guard let containerURL else { return nil }
        try? FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
        return containerURL.appendingPathComponent(payloadFilename)
    }
}
