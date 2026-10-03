import AVFoundation
import Observation

@MainActor
@Observable
final class SpeechService {
    private let synth = AVSpeechSynthesizer()
    private(set) var hasThaiVoice = false

    init() {
        refresh()
    }

    func refresh() {
        hasThaiVoice = AVSpeechSynthesisVoice.speechVoices().contains { voice in
            voice.language.lowercased().hasPrefix("th")
        }
    }

    private var bridge: SpeechBridge?

    /// 没有 th-TH 声音时不播放，避免系统用英语把泰文念错。
    /// `rateScale` 乘在系统默认语速上，1 是原速。
    @discardableResult
    func speak(_ text: String, rateScale: Double = 0.82, whenFinished: (() -> Void)? = nil) -> Bool {
        guard let voice = AVSpeechSynthesisVoice(language: "th-TH") else {
            hasThaiVoice = false
            return false
        }
        if bridge == nil {
            let bridge = SpeechBridge()
            synth.delegate = bridge
            self.bridge = bridge
        }
        synth.stopSpeaking(at: .immediate)
        bridge?.onFinish = whenFinished
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        let scale = min(1.3, max(0.45, rateScale))
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * Float(scale)
        synth.speak(utterance)
        return true
    }

    func stop() {
        bridge?.onFinish = nil
        synth.stopSpeaking(at: .immediate)
    }
}

private final class SpeechBridge: NSObject, AVSpeechSynthesizerDelegate {
    var onFinish: (() -> Void)?

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let callback = onFinish
        onFinish = nil
        callback?()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        onFinish = nil
    }
}
