import AVFoundation
import Foundation

enum WaveformExtractor {
    static func peaks(url: URL, fallback: [Float], buckets: Int = 42) -> [Float] {
        let extracted = (try? peaks(from: url, buckets: buckets)) ?? []
        if extracted.contains(where: { $0 > 0.02 }) {
            return extracted
        }
        return downsample(fallback, buckets: buckets)
    }

    static func peaks(from url: URL, buckets: Int) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let frames = AVAudioFrameCount(file.length)
        guard frames > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else {
            return []
        }
        try file.read(into: buffer)
        guard let channel = buffer.floatChannelData?[0] else { return [] }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return [] }

        let bucketSize = max(1, count / max(buckets, 1))
        var peaks: [Float] = []
        var index = 0
        while index < count && peaks.count < buckets {
            let end = min(count, index + bucketSize)
            var peak: Float = 0
            for sample in index..<end {
                peak = max(peak, abs(channel[sample]))
            }
            peaks.append(peak)
            index = end
        }
        return normalize(peaks)
    }

    static func downsample(_ values: [Float], buckets: Int) -> [Float] {
        guard !values.isEmpty else { return [] }
        if values.count <= buckets {
            return normalize(values)
        }
        let size = max(1, Int((Double(values.count) / Double(buckets)).rounded(.up)))
        var peaks: [Float] = []
        var index = 0
        while index < values.count && peaks.count < buckets {
            let end = min(values.count, index + size)
            peaks.append(values[index..<end].max() ?? 0)
            index = end
        }
        return normalize(peaks)
    }

    private static func normalize(_ values: [Float]) -> [Float] {
        let peak = values.max() ?? 0
        guard peak > 0 else { return values }
        return values.map { min(1, $0 / peak) }
    }
}
