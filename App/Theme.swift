import SwiftUI
import ThaiLearnCore

enum Ink {
    static let paper = Color(red: 0.965, green: 0.945, blue: 0.910)
    static let card = Color(red: 0.995, green: 0.986, blue: 0.968)
    static let ink = Color(red: 0.145, green: 0.176, blue: 0.161)
    static let muted = Color(red: 0.40, green: 0.42, blue: 0.38)
    static let lacquer = Color(red: 0.70, green: 0.28, blue: 0.16)
    static let leaf = Color(red: 0.16, green: 0.40, blue: 0.34)
    static let river = Color(red: 0.24, green: 0.36, blue: 0.52)
    static let line = Color(red: 0.86, green: 0.82, blue: 0.74)
}

extension ConsonantClass {
    var tint: Color {
        switch self {
        case .mid: return Ink.lacquer
        case .high: return Ink.leaf
        case .low: return Ink.river
        }
    }
}

struct PaperBackground: ViewModifier {
    func body(content: Content) -> some View {
        // Color fills the column, including under the title bar. The content
        // itself stays in the safe area, so it does not slide under the toolbar.
        content.background {
            Ink.paper.ignoresSafeArea()
        }
    }
}

extension View {
    func paper() -> some View {
        modifier(PaperBackground())
    }
}

struct ThaiLine: View {
    var text: String
    var size: CGFloat = 44

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .regular, design: .serif))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct PlayButton: View {
    @Environment(SpeechService.self) private var speech
    var text: String
    var title: String = "听"

    var body: some View {
        Button {
            speech.speak(text)
        } label: {
            Label(title, systemImage: "speaker.wave.2")
        }
        .disabled(!speech.hasThaiVoice)
    }
}

struct VoiceBanner: View {
    @Environment(SpeechService.self) private var speech

    var body: some View {
        if !speech.hasThaiVoice {
            VStack(alignment: .leading, spacing: 6) {
                Label("还没有泰语语音", systemImage: "speaker.slash")
                    .font(.headline)
                Text("打开「系统设置」→「辅助功能」→「朗读内容」。在「系统声音」里点「管理声音…」，下载泰语（ไทย / th-TH）。下完回到这里，播放就会用这个声音。")
                    .font(.callout)
                    .foregroundStyle(Ink.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Ink.card, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Ink.line, lineWidth: 1)
            )
        }
    }
}

struct CardShell<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Ink.card, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Ink.line, lineWidth: 1)
            )
    }
}
