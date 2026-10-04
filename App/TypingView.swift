#if os(macOS)
import AppKit
import Carbon
#endif
import SwiftUI
import ThaiLearnCore

struct TypingView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var lessonID: String? = "home-left"
    @State private var typed = ""
    @State private var started: Date?
    @State private var recorded = false
    @State private var previewShift = false
    @State private var thaiKeyboard = false

    private var compact: Bool {
        #if os(iOS)
        sizeClass == .compact
        #else
        false
        #endif
    }

    var body: some View {
        let lessons = model.catalog.map { TypingCourse.lessons(in: $0) } ?? []
        let lesson = lessons.first { $0.id == lessonID } ?? (lessonID == "weak" ? lessons.first : lessons.first)
        Group {
            if compact {
                compactBody(lessons: lessons, lesson: lesson)
            } else {
                wideBody(lessons: lessons, lesson: lesson)
            }
        }
        .navigationTitle("打字")
        .onAppear {
            thaiKeyboard = ThaiInputSource.isActive()
        }
        #if os(macOS)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            thaiKeyboard = ThaiInputSource.isActive()
        }
        #endif
        .onChange(of: lessonID) { _, _ in
            resetLine()
        }
    }

    private func wideBody(lessons: [TypingLesson], lesson: TypingLesson?) -> some View {
        HStack(spacing: 0) {
            List(selection: $lessonID) {
                ForEach(lessons) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                        if let best = model.progress.typing.best[item.id] {
                            Text("最好 \(Int(best.cpm.rounded())) 字/分钟")
                                .font(.caption)
                                .foregroundStyle(Ink.muted)
                        }
                    }
                    .tag(Optional(item.id))
                    .padding(.vertical, 4)
                }
                Text("薄弱键")
                    .tag(Optional("weak"))
                    .padding(.vertical, 4)
            }
            .listStyle(.sidebar)
            .frame(minWidth: 180, idealWidth: 210, maxWidth: 260)

            if let lesson {
                practice(lesson)
            }
            stats
                .frame(width: 230)
        }
    }

    private func compactBody(lessons: [TypingLesson], lesson: TypingLesson?) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Picker("课", selection: $lessonID) {
                    ForEach(lessons) { item in
                        Text(item.title).tag(Optional(item.id))
                    }
                    Text("薄弱键").tag(Optional("weak"))
                }
                if let lesson {
                    practice(lesson)
                }
                stats
            }
        }
    }

    private func practice(_ lesson: TypingLesson) -> some View {
        let source = lessonID == "weak" ? TypingCourse.weakDrill(from: model.progress.typing) : lesson
        let shown = model.progress.typing.qwertyFallback ? typed : typed
        let diff = TypingCompare.diff(expected: source.text, typed: shown)
        let shifted = previewShift || (diff.focus.flatMap { KedmaneeKeyboard.producer(of: $0.expected)?.shifted } ?? false)
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(source.title).font(.title2.bold())
                Text(source.detail)
                    .foregroundStyle(Ink.muted)
                if showsBanner(typed: shown) {
                    banner
                }
                prompt(diff)
                TextField("在这里打字", text: Binding(
                    get: { typed },
                    set: { updateTyped($0, expected: source.text) }
                ))
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 22, design: .serif))
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                if diff.focus?.status == .wrong {
                    Text("这个字不对。按删除键退回，再打一次。")
                        .font(.callout)
                        .foregroundStyle(Ink.lacquer)
                }
                if diff.finished {
                    Text("这一行对了。")
                        .foregroundStyle(Ink.leaf)
                }
                keyboard(shifted: shifted, next: diff.focus?.expected)
                HStack {
                    Button(model.progress.typing.qwertyFallback ? "正在用英文字母键位" : "改用英文字母键位") {
                        model.setTypingFallback(!model.progress.typing.qwertyFallback)
                        resetLine()
                    }
                    Button("重打这一行") { resetLine() }
                    Button("看 Shift 档") { previewShift.toggle() }
                }
            }
            .padding(24)
            .frame(maxWidth: 760, alignment: .leading)
        }
    }

    private var stats: some View {
        let typing = model.progress.typing
        let minutes = Int(typing.practicedSeconds / 60)
        let today = Int(typing.seconds(on: model.today) / 60)
        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("成绩").font(.headline)
                Text("今天 \(today) 分钟")
                Text("累计 \(minutes) 分钟")
                    .foregroundStyle(Ink.muted)
                Text("薄弱的键")
                    .font(.headline)
                    .padding(.top, 8)
                if typing.weakKeys.isEmpty {
                    Text("还没有错键。")
                        .foregroundStyle(Ink.muted)
                } else {
                    ForEach(Array(typing.weakKeys.prefix(6)), id: \.key) { item in
                        HStack {
                            Text(KedmaneeKeyboard.label(for: item.key))
                                .font(.title3)
                            Spacer()
                            Text("错 \(item.misses) 次")
                                .foregroundStyle(Ink.muted)
                        }
                    }
                    Button("练这些键") { lessonID = "weak" }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Ink.card)
    }

    private var banner: some View {
        VStack(alignment: .leading, spacing: 6) {
            #if os(iOS)
            Text("请用系统泰文键盘")
            #else
            Text("当前不是泰文输入法")
            #endif
                .font(.headline)
            #if os(iOS)
            Text("在键盘上的地球仪键切到「ไทย」。下面的键位只用来看下一键，点它不会输入。")
            #else
            Text("打开「系统设置」→「键盘」→「输入法」，添加「泰文」。然后用 Ctrl+Space，或按 Fn（地球仪键）切换。打出泰文以后，这条提示会消失。也可以先用下面的英文字母键位练习。")
            #endif
                .font(.callout)
                .foregroundStyle(Ink.muted)
                .fixedSize(horizontal: false, vertical: true)
            #if os(macOS)
            Button("重新检测") { thaiKeyboard = ThaiInputSource.isActive() }
            #endif
        }
        .padding(12)
        .background(Ink.card, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Ink.line, lineWidth: 1))
    }

    private func prompt(_ diff: TypingDiff) -> some View {
        FlowLayout(spacing: 4) {
            ForEach(Array(diff.marks.enumerated()), id: \.offset) { _, mark in
                Text(mark.expected == " " ? "␣" : KedmaneeKeyboard.label(for: mark.typed ?? mark.expected))
                    .font(.system(size: 22, design: .serif))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .foregroundStyle(color(mark.status))
                    .background(mark.status == .wrong ? Ink.lacquer.opacity(0.15) : Color.clear, in: RoundedRectangle(cornerRadius: 4))
            }
        }
    }

    private func keyboard(shifted: Bool, next: String?) -> some View {
        VStack(spacing: 6) {
            ForEach(KedmaneeKeyboard.rowOrder, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(KedmaneeKeyboard.keys(in: row)) { key in
                        keycap(key, shifted: shifted, next: next)
                    }
                }
            }
            Text("空格")
                .font(.caption)
                .padding(.horizontal, 28)
                .padding(.vertical, 8)
                .background(next == " " ? Ink.lacquer.opacity(0.25) : Ink.card, in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Ink.line, lineWidth: 1))
        }
    }

    private func keycap(_ key: KedmaneeKey, shifted: Bool, next: String?) -> some View {
        let label = shifted ? key.shiftedLabel : key.plainLabel
        let active = next == (shifted ? key.shifted : key.plain)
        return Button {
            #if os(iOS)
            #else
            updateTyped(typed + (shifted ? key.shifted : key.plain), expected: currentText)
            #endif
        } label: {
            VStack(spacing: 0) {
                Text(key.usPlain.uppercased())
                    .font(.system(size: 9))
                    .foregroundStyle(Ink.muted)
                Text(label)
                    .font(.system(size: 16, design: .serif))
                if key.homeBump {
                    Circle().fill(Ink.ink).frame(width: 4, height: 4)
                }
            }
            .frame(width: 46, height: 48)
            .background(active ? Ink.lacquer.opacity(0.28) : fingerColor(key.finger).opacity(0.22), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(active ? Ink.lacquer : Ink.line, lineWidth: active ? 2 : 1))
        }
        .buttonStyle(.plain)
        .help(key.finger.chinese)
    }

    private var currentText: String {
        if lessonID == "weak" { return TypingCourse.weakDrill(from: model.progress.typing).text }
        return model.catalog.flatMap { TypingCourse.lessons(in: $0).first { $0.id == lessonID }?.text } ?? ""
    }

    private func updateTyped(_ raw: String, expected: String) {
        let next = model.progress.typing.qwertyFallback ? TypingInput.thai(fromQWERTY: raw) : raw
        if typed.isEmpty, !next.isEmpty { started = Date() }
        typed = next
        if typed.unicodeScalars.contains(where: { (0x0E00...0x0E7F).contains($0.value) }) {
            thaiKeyboard = true
        }
        let diff = TypingCompare.diff(expected: expected, typed: typed)
        guard diff.finished, !recorded, let started else { return }
        recorded = true
        let seconds = max(0.5, Date().timeIntervalSince(started))
        let score = TypingMetrics.score(correct: diff.correct, wrong: diff.wrong, seconds: seconds)
        model.recordTyping(lesson: lessonID ?? "weak", score: score, expected: expected, typed: typed)
    }

    private func resetLine() {
        typed = ""
        started = nil
        recorded = false
    }

    private func showsBanner(typed: String) -> Bool {
        if model.progress.typing.qwertyFallback { return false }
        if typed.unicodeScalars.contains(where: { (0x0E00...0x0E7F).contains($0.value) }) { return false }
        return !thaiKeyboard
    }

    private func color(_ status: TypingMark) -> Color {
        switch status {
        case .pending: return Ink.muted
        case .correct: return Ink.leaf
        case .wrong: return Ink.lacquer
        }
    }

    private func fingerColor(_ finger: TypingFinger) -> Color {
        switch finger {
        case .leftPinky: return Ink.lacquer
        case .leftRing: return Ink.river
        case .leftMiddle: return Ink.leaf
        case .leftIndex: return Color(red: 0.45, green: 0.32, blue: 0.55)
        case .rightIndex: return Color(red: 0.55, green: 0.38, blue: 0.22)
        case .rightMiddle: return Ink.leaf
        case .rightRing: return Ink.river
        case .rightPinky: return Ink.lacquer
        case .thumb: return Ink.muted
        }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 640
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
    }
}

enum ThaiInputSource {
    /// macOS reports the selected keyboard layout. Thai is a layout, not a converting input method.
    /// A stale ASCII layout can still be reported for a moment after switching; typed Thai hides the banner.
    static func isActive() -> Bool {
        #if os(iOS)
        return false
        #else
        guard let unmanaged = TISCopyCurrentKeyboardInputSource() else { return false }
        let source = unmanaged.takeRetainedValue()
        guard let raw = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguages) else { return false }
        let languages = Unmanaged<CFArray>.fromOpaque(raw).takeUnretainedValue() as NSArray
        for value in languages {
            if let language = value as? String, language.lowercased().hasPrefix("th") {
                return true
            }
        }
        return false
        #endif
    }
}
