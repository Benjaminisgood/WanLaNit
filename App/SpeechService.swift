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

    /// 没有 th-TH 声音时不播放，避免系统用英语把泰文念错。
    @discardableResult
    func speak(_ text: String) -> Bool {
        guard let voice = AVSpeechSynthesisVoice(language: "th-TH") else {
            hasThaiVoice = false
            return false
        }
        synth.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.82
        synth.speak(utterance)
        return true
    }
}
