import AVFoundation
import Speech

/// Records a short take and can hand it to the on-device Thai recognizer.
final class MicCapture {
    private(set) var level: Double = 0
    private(set) var recording = false
    private var engine: AVAudioEngine?
    private var samples: [Float] = []
    private var sampleRate: Double = 16_000
    private let lock = NSLock()

    func requestAccess() async -> Bool {
        let microphone = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            #if os(iOS)
            AVAudioSession.sharedInstance().requestRecordPermission { continuation.resume(returning: $0) }
            #else
            AVCaptureDevice.requestAccess(for: .audio) { continuation.resume(returning: $0) }
            #endif
        }
        let speech = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        return microphone && speech
    }

    func start() throws {
        stopEngine()
        lock.lock()
        samples = []
        lock.unlock()
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try session.setActive(true)
        #endif
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw MicError.noInput
        }
        sampleRate = format.sampleRate
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.take(buffer)
        }
        engine.prepare()
        try engine.start()
        self.engine = engine
        recording = true
    }

    func stop() -> (samples: [Float], rate: Double) {
        stopEngine()
        recording = false
        level = 0
        lock.lock()
        let copy = samples
        samples = []
        lock.unlock()
        return (copy, sampleRate)
    }

    private func stopEngine() {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
    }

    private func take(_ buffer: AVAudioPCMBuffer) {
        guard let channel = buffer.floatChannelData?.pointee else { return }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return }
        var chunk: [Float] = []
        chunk.reserveCapacity(count)
        var sum: Float = 0
        for index in 0..<count {
            let value = channel[index]
            chunk.append(value)
            sum += value * value
        }
        let rms = sqrt(sum / Float(count))
        lock.lock()
        samples.append(contentsOf: chunk)
        level = min(1, Double(rms) * 8)
        lock.unlock()
    }

    func currentLevel() -> Double {
        lock.lock()
        let value = level
        lock.unlock()
        return value
    }
}

enum MicError: Error {
    case noInput
}

enum AppleThaiSpeech {
    static func transcribe(samples: [Float], sampleRate: Double) async throws -> String {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "th-TH")), recognizer.isAvailable else {
            throw MicError.noInput
        }
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))
        else { throw MicError.noInput }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { pointer in
            guard let base = pointer.baseAddress, let channel = buffer.floatChannelData else { return }
            channel[0].update(from: base, count: samples.count)
        }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = false
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        request.append(buffer)
        request.endAudio()
        return try await withCheckedThrowingContinuation { continuation in
            let gate = ResumeOnce()
            recognizer.recognitionTask(with: request) { result, error in
                if let result, result.isFinal {
                    gate.resume { continuation.resume(returning: result.bestTranscription.formattedString) }
                } else if let error {
                    gate.resume { continuation.resume(throwing: error) }
                }
            }
        }
    }
}

private final class ResumeOnce {
    private let lock = NSLock()
    private var done = false

    func resume(_ body: () -> Void) {
        lock.lock()
        if done {
            lock.unlock()
            return
        }
        done = true
        lock.unlock()
        body()
    }
}
