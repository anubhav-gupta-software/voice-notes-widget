import AVFoundation
import UIKit

struct RecordingResult: Equatable {
    var url: URL
    var duration: TimeInterval
    var samples: [Float]
}

@MainActor
@Observable
final class VoiceRecorder {
    private(set) var isRecording = false
    private(set) var elapsed: TimeInterval = 0
    private(set) var samples: [Float] = []
    private(set) var permissionDenied = false
    private(set) var finishedResult: RecordingResult?
    private(set) var failure: String?

    private var recorder: AVAudioRecorder?
    private var meterTask: Task<Void, Never>?
    private var outputURL: URL?
    private var didPublish = false
    private let delegate = RecorderDelegate()

    init() {
        delegate.owner = self
    }

    func start() async -> Bool {
        discard()
        failure = nil
        let granted = await AVAudioApplication.requestRecordPermission()
        permissionDenied = !granted
        guard granted else { return false }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try session.setActive(true)
        } catch {
            failure = "The microphone couldn't start."
            return false
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("recording-\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 64_000,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.delegate = delegate
            recorder.isMeteringEnabled = true
            recorder.prepareToRecord()
            guard recorder.record(forDuration: Theme.recordingLimit) else {
                failure = "Recording didn't start."
                return false
            }
            self.recorder = recorder
            outputURL = url
            didPublish = false
            isRecording = true
            elapsed = 0
            samples = []
            UIApplication.shared.isIdleTimerDisabled = true
            startMeter()
            return true
        } catch {
            failure = "Recording didn't start."
            return false
        }
    }

    func stop() {
        meterTask?.cancel()
        UIApplication.shared.isIdleTimerDisabled = false
        recorder?.stop()
        isRecording = false
        publishResult()
    }

    func discard() {
        meterTask?.cancel()
        UIApplication.shared.isIdleTimerDisabled = false
        recorder?.delegate = nil
        recorder?.stop()
        recorder = nil
        isRecording = false
        if let outputURL {
            try? FileManager.default.removeItem(at: outputURL)
        }
        outputURL = nil
        finishedResult = nil
        elapsed = 0
        samples = []
        didPublish = false
    }

    /// Clears the preview without deleting a file that has already been moved into the library.
    func reset() {
        meterTask?.cancel()
        UIApplication.shared.isIdleTimerDisabled = false
        recorder = nil
        outputURL = nil
        finishedResult = nil
        elapsed = 0
        samples = []
        isRecording = false
        didPublish = false
        failure = nil
    }

    fileprivate func handleAutoFinish(success: Bool) {
        meterTask?.cancel()
        UIApplication.shared.isIdleTimerDisabled = false
        isRecording = false
        if success {
            publishResult()
        } else if finishedResult == nil {
            failure = "That recording didn't stick."
        }
    }

    private func startMeter() {
        meterTask?.cancel()
        meterTask = Task { @MainActor in
            while !Task.isCancelled && isRecording {
                sampleMeter()
                try? await Task.sleep(for: .milliseconds(80))
            }
        }
    }

    private func sampleMeter() {
        guard let recorder, recorder.isRecording else { return }
        recorder.updateMeters()
        let power = recorder.averagePower(forChannel: 0)
        let linear = min(1, max(0, pow(10, power / 20)))
        samples.append(linear)
        if samples.count > 220 {
            samples.removeFirst(samples.count - 220)
        }
        elapsed = recorder.currentTime
    }

    private func publishResult() {
        guard !didPublish, let url = outputURL else { return }
        didPublish = true
        let duration = max(elapsed, recorder?.currentTime ?? 0)
        finishedResult = RecordingResult(
            url: url,
            duration: duration,
            samples: WaveformExtractor.downsample(samples, buckets: 42)
        )
        recorder = nil
        isRecording = false
    }
}

private final class RecorderDelegate: NSObject, AVAudioRecorderDelegate {
    weak var owner: VoiceRecorder?

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor [weak owner] in
            owner?.handleAutoFinish(success: flag)
        }
    }
}
