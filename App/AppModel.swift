import Foundation
import Observation
import ThaiLearnCore

@MainActor
@Observable
final class AppModel {
    let speech: SpeechService
    private let store = ProgressStore.live()

    private(set) var catalog: Catalog?
    private(set) var loadError: String?
    var importMessage: String?
    var progress: LearningProgress
    var active: ActiveSession?
    var selectedSection: AppSection? = .today
    private(set) var credentials: [AICredential] = []
    var assignments = AIAssignments()
    var aiNotice: String?
    private var playToken = 0

    init() {
        speech = SpeechService()
        credentials = KeychainVault.loadCredentials()
        assignments = KeychainVault.loadAssignments()
        let stored = store.load()
        progress = stored
        switch CatalogLocation.load() {
        case .success(let catalog):
            self.catalog = catalog
            if let resume = stored.resume, resume.day == .today {
                active = ActiveSession.restore(resume)
            }
        case .failure(let error):
            loadError = error.issues.joined(separator: "\n")
        }
    }

    var today: CivilDay { .today }

    func report() -> ProgressReport? {
        guard let catalog else { return nil }
        return ProgressReport.make(catalog: catalog, progress: progress, today: today)
    }

    func stats() -> StudyStats? {
        guard let catalog else { return nil }
        return StudyStats.make(catalog: catalog, progress: progress, today: today)
    }

    func setDesiredRetention(_ value: Double) {
        progress.desiredRetention = min(0.97, max(0.80, value))
        store.save(progress)
    }

    func setNewCardLimit(_ value: Int) {
        progress.newCardLimit = min(60, max(0, value))
        store.save(progress)
    }

    func setUnlockAll(_ value: Bool) {
        progress.unlockAll = value
        store.save(progress)
    }

    func setTypingFallback(_ enabled: Bool) {
        progress.setTypingFallback(enabled)
        store.save(progress)
    }

    func recordTyping(lesson id: String, score: TypingScore, expected: String, typed: String) {
        progress.recordTyping(lesson: id, score: score, expected: expected, typed: typed, on: today)
        store.save(progress)
    }

    func markPassageRead(_ id: String) {
        progress.recordPassageRead(id, on: today)
        store.save(progress)
    }

    func recordPassageQuiz(id: String, correct: Int, asked: Int) {
        progress.recordPassageQuiz(id: id, correct: correct, asked: asked)
        store.save(progress)
    }

    func recordPassageDictation(id: String, completed: Int) {
        progress.recordPassageDictation(id: id, completed: completed)
        store.save(progress)
    }

    func planToday() -> PlannedSession? {
        guard let catalog else { return nil }
        return StudySession.planToday(catalog: catalog, progress: progress, today: today)
    }

    func beginToday() {
        if let resume = progress.resume, resume.day == today, !resume.items.isEmpty {
            active = ActiveSession.restore(resume)
            return
        }
        guard let plan = planToday(), !plan.items.isEmpty else { return }
        begin(plan)
    }

    func beginDeck(_ deckID: String) {
        guard let catalog else { return }
        let plan = StudySession.planDeck(deckID: deckID, catalog: catalog, progress: progress, today: today)
        guard !plan.items.isEmpty else { return }
        begin(plan)
    }

    func grade(_ grade: Grade) {
        guard var session = active, !session.isFinished else { return }
        let ref = session.current
        session.grade(grade, progress: &progress)
        if let ref, let catalog, ref.kind == .word {
            ReaderState.sync(ref, catalog: catalog, progress: &progress)
        }
        active = session
        store.save(progress)
    }

    func importPasted(title: String, body: String) {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        progress.library.append(ReaderDocument(
            id: UUID().uuidString,
            title: name.isEmpty ? "粘贴的文章" : name,
            body: trimmed,
            source: "粘贴"
        ))
        importMessage = nil
        store.save(progress)
    }

    func importFile(_ url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            importMessage = "这个文件不是 UTF-8 文本。"
            return
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            importMessage = "文件是空的。"
            return
        }
        progress.library.append(ReaderDocument(
            id: UUID().uuidString,
            title: url.deletingPathExtension().lastPathComponent,
            body: trimmed,
            source: "文件"
        ))
        importMessage = nil
        store.save(progress)
    }

    func importRemote(_ raw: String) async {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let scheme = url.scheme, scheme == "https" || scheme == "http" else {
            importMessage = "网址看起来不对。"
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let html = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
            let body = HTMLText.plainText(from: html)
            guard !body.isEmpty else {
                importMessage = "这个页面里没有能取出的文字。"
                return
            }
            let title = HTMLText.title(from: html) ?? url.host ?? "网页"
            progress.library.append(ReaderDocument(
                id: UUID().uuidString,
                title: title,
                body: body,
                source: url.absoluteString
            ))
            importMessage = nil
            store.save(progress)
        } catch {
            importMessage = "抓取失败。"
        }
    }

    func setWordMark(_ thai: String, status: WordMark, level: Int) {
        ReaderState.setMark(status, level: level, thai: thai, progress: &progress)
        store.save(progress)
    }

    func addWordToReview(thai: String, sentence: String) {
        guard let catalog else { return }
        ReaderState.addToReview(thai: thai, sentence: sentence, catalog: catalog, progress: &progress, on: today)
        store.save(progress)
    }

    func closeSession() {
        active = nil
    }

    var canSpeak: Bool {
        if progress.ai.useAIVoice, credential(for: .speech) != nil { return true }
        return speech.hasThaiVoice
    }

    var voiceChoices: [String] {
        let preset = credential(for: .speech)?.provider.voices ?? AIProvider.openai.voices
        if preset.contains(progress.ai.voice) { return preset }
        return preset + [progress.ai.voice]
    }

    func setUseAIVoice(_ enabled: Bool) {
        progress.ai.useAIVoice = enabled
        store.save(progress)
    }

    func setAIVoice(_ voice: String) {
        progress.ai.voice = voice
        store.save(progress)
    }

    func setAIRate(_ value: Double) {
        progress.ai.rate = min(1.2, max(0.5, value))
        store.save(progress)
    }

    func setAIDifficulty(_ value: String) {
        progress.ai.difficulty = value
        store.save(progress)
    }

    func setAIHints(_ enabled: Bool) {
        progress.ai.showHints = enabled
        store.save(progress)
    }

    func setAIDailyCap(_ value: Int) {
        progress.ai.usage.dailyCap = min(200, max(0, value))
        store.save(progress)
    }

    func saveAI(credentials: [AICredential], assignments: AIAssignments) {
        do {
            try KeychainVault.save(credentials: credentials, assignments: assignments)
            self.credentials = credentials
            self.assignments = assignments
            aiNotice = "已放进钥匙串。progress.json 里没有钥匙。"
        } catch {
            aiNotice = "钥匙串没有写成。"
        }
    }

    func deleteCredential(_ id: String) {
        var next = assignments
        if next.chatID == id { next.chatID = nil }
        if next.speechID == id { next.speechID = nil }
        if next.transcriptionID == id { next.transcriptionID = nil }
        saveAI(credentials: credentials.filter { $0.id != id }, assignments: next)
    }

    func credential(for capability: AICapability) -> AICredential? {
        let chosen: String?
        switch capability {
        case .chat: chosen = assignments.chatID
        case .speech: chosen = assignments.speechID
        case .transcription: chosen = assignments.transcriptionID
        }
        if let chosen, let match = credentials.first(where: { $0.id == chosen }) {
            return match.provider.capabilities.contains(capability) ? match : nil
        }
        return credentials.first { $0.provider.capabilities.contains(capability) }
    }

    func probe(_ credential: AICredential, model: String?) async -> String {
        await AIClients.probe(credential, model: model, transport: AIClients.transport())
    }

    func stopPlayback() {
        playToken += 1
        speech.stop()
    }

    func play(_ text: String, rate: Double? = nil, whenFinished: (() -> Void)? = nil) {
        playToken += 1
        let token = playToken
        let speed = rate ?? progress.ai.rate
        guard progress.ai.useAIVoice, let credential = credential(for: .speech) else {
            if progress.ai.useAIVoice {
                aiNotice = "还没有 AI 朗读的钥匙，先用系统声音。"
            }
            if !speech.speak(text, rateScale: speed, whenFinished: whenFinished) {
                whenFinished?()
            }
            return
        }
        let voice = resolvedVoice(credential)
        let modelName = credential.model(for: .speech, override: assignments.speechModel)
        let digest = AICacheKey.digest(
            text: text,
            voice: voice,
            model: "\(credential.provider.rawValue):\(modelName)",
            speed: speed
        )
        if let cached = TTSCache.read(digest) {
            if !speech.playAudio(cached, whenFinished: whenFinished),
               !speech.speak(text, rateScale: speed, whenFinished: whenFinished) {
                whenFinished?()
            }
            return
        }
        Task {
            do {
                try reserveAICall()
                let speaker = try AIClients.speech(credential, model: modelName, voice: voice, transport: AIClients.transport())
                let data = try await speaker.synthesize(text: text, speed: max(speed, 0.5))
                guard token == playToken else { return }
                TTSCache.write(digest, data: data)
                if !speech.playAudio(data, whenFinished: whenFinished),
                   !speech.speak(text, rateScale: speed, whenFinished: whenFinished) {
                    whenFinished?()
                }
            } catch {
                guard token == playToken else { return }
                aiNotice = (error as? AIClientError)?.description ?? "AI 朗读失败，改用系统声音。"
                if !speech.speak(text, rateScale: speed, whenFinished: whenFinished) {
                    whenFinished?()
                }
            }
        }
    }

    func generateExercises(topic: String) async -> (AIExerciseBatch, String) {
        guard let catalog else { return (AIExerciseBatch(exercises: []), "课程还没载入。") }
        let local = LocalExercises.make(catalog: catalog, progress: progress, topic: topic)
        guard let credential = credential(for: .chat) else {
            return (local, "没有对话钥匙，这是本地题目。不联网也能做。")
        }
        do {
            try reserveAICall()
            let chat = try AIClients.chat(
                credential,
                model: credential.model(for: .chat, override: assignments.chatModel),
                transport: AIClients.transport()
            )
            let words = LearnedWords.list(catalog: catalog, progress: progress, topic: topic, limit: 12).map(\.thai)
            let batch = try await AIExerciseService.generate(
                chat: chat,
                words: words,
                topic: topic.isEmpty ? "日常生活" : topic,
                level: progress.ai.difficulty
            )
            return (batch, "按学过的词出的题。")
        } catch {
            let reason = (error as? AIClientError)?.description ?? "AI 没有出成"
            return (local, "\(reason)。改用本地题目。")
        }
    }

    func grade(text: String) async -> AICorrection {
        guard let catalog else {
            return AICorrection(corrected: text, romanization: "", explanation: "课程还没载入。", score: 0)
        }
        guard let credential = credential(for: .chat) else {
            return AIGrader.offline(text: text, catalog: catalog)
        }
        do {
            try reserveAICall()
            let chat = try AIClients.chat(
                credential,
                model: credential.model(for: .chat, override: assignments.chatModel),
                transport: AIClients.transport()
            )
            return try await AIGrader.grade(chat: chat, text: text)
        } catch {
            var offline = AIGrader.offline(text: text, catalog: catalog)
            offline.explanation = "\((error as? AIClientError)?.description ?? "AI 没有批改成")。\(offline.explanation)"
            return offline
        }
    }

    func explainSpeech(target: String, transcript: String) async -> String {
        let local = SpeakScore.honesty
        guard let credential = credential(for: .chat) else { return local }
        do {
            try reserveAICall()
            let chat = try AIClients.chat(
                credential,
                model: credential.model(for: .chat, override: assignments.chatModel),
                transport: AIClients.transport()
            )
            let raw = try await chat.complete(messages: [
                .system("根据转写和原句，用两三句中文说说可能的声调或元音长短问题。明确这不是声学分析。只输出 JSON：{\"feedback\":\"...\"}"),
                .user("原句：\(target)\n转写：\(transcript)")
            ], jsonObject: true)
            struct Feedback: Decodable { var feedback: String? }
            let note = (try? AIJSON.decode(raw, as: Feedback.self))?.feedback ?? raw
            return note + " " + local
        } catch {
            return "\((error as? AIClientError)?.description ?? "") \(local)"
        }
    }

    func sendChat(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        progress.recordDialogue(AIChatTurn(id: UUID().uuidString, role: "user", thai: trimmed, chinese: ""))
        store.save(progress)
        guard let credential = credential(for: .chat) else {
            aiNotice = "先在下面的 AI 设置里导入钥匙，才能对话。没有钥匙时仍可以朗读学过的句子。"
            return
        }
        do {
            try reserveAICall()
            let chat = try AIClients.chat(
                credential,
                model: credential.model(for: .chat, override: assignments.chatModel),
                transport: AIClients.transport()
            )
            let raw = try await chat.complete(
                messages: AIPartner.messages(
                    history: progress.ai.dialogue,
                    difficulty: progress.ai.difficulty,
                    hints: progress.ai.showHints
                ),
                jsonObject: true
            )
            let reply = AIPartner.decode(raw)
            progress.recordDialogue(AIChatTurn(id: UUID().uuidString, role: "assistant", thai: reply.thai, chinese: reply.chinese))
            store.save(progress)
        } catch {
            aiNotice = (error as? AIClientError)?.description ?? "对话没有发出去。"
        }
    }

    func clearDialogue() {
        progress.ai.dialogue = []
        store.save(progress)
    }

    func saveSpeakAttempt(target: String, transcript: String, score: Int) {
        progress.recordSpeakAttempt(SpeakAttempt(
            id: UUID().uuidString,
            target: target,
            transcript: transcript,
            score: score,
            on: today.iso
        ))
        store.save(progress)
    }

    func transcribe(samples: [Float], rate: Double) async -> String {
        guard !samples.isEmpty else {
            aiNotice = "没有录到声音。"
            return ""
        }
        let wav = WAVAudio.pcm16(samples: samples, sampleRate: rate)
        if let credential = credential(for: .transcription) {
            do {
                try reserveAICall()
                let recognizer = try AIClients.recognizer(
                    credential,
                    model: credential.model(for: .transcription, override: assignments.transcriptionModel),
                    transport: AIClients.transport()
                )
                return try await recognizer.transcribe(audioWAV: wav)
            } catch {
                aiNotice = (error as? AIClientError)?.description ?? "云端识别失败，改用系统识别。"
            }
        }
        do {
            return try await AppleThaiSpeech.transcribe(samples: samples, sampleRate: rate)
        } catch {
            aiNotice = "这台 Mac 没有认出泰语。系统识别需要泰语语音识别；也可以在 AI 设置里选带转写的钥匙。"
            return ""
        }
    }

    private func resolvedVoice(_ credential: AICredential) -> String {
        let voices = credential.provider.voices
        if voices.contains(progress.ai.voice) { return progress.ai.voice }
        return voices.first ?? progress.ai.voice
    }

    private func reserveAICall() throws {
        guard progress.ai.usage.allows(today) else { throw AIClientError.capped }
        progress.ai.usage.record(on: today)
        store.save(progress)
    }

    private func begin(_ plan: PlannedSession) {
        let session = StudySession.start(plan)
        progress.resume = session.snapshot
        active = session
        store.save(progress)
    }
}

enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case today
    case tones
    case decks
    case script
    case culture
    case vocab
    case reader
    case typing
    case passages
    case ai
    case stats

    var id: Self { self }

    var title: String {
        switch self {
        case .today: return "今天"
        case .tones: return "声调"
        case .decks: return "句子"
        case .script: return "文字"
        case .culture: return "文化"
        case .vocab: return "词汇"
        case .reader: return "阅读"
        case .typing: return "打字"
        case .passages: return "精读"
        case .ai: return "AI 练习"
        case .stats: return "统计"
        }
    }

    var symbol: String {
        switch self {
        case .today: return "sun.max"
        case .tones: return "waveform"
        case .decks: return "text.bubble"
        case .script: return "character.book.closed"
        case .culture: return "leaf"
        case .vocab: return "text.book.closed"
        case .reader: return "book"
        case .typing: return "keyboard"
        case .passages: return "book.fill"
        case .ai: return "sparkles"
        case .stats: return "chart.bar"
        }
    }
}

enum CatalogLocation {
    static func load() -> Result<Catalog, ContentError> {
        ContentLoader.loadApplicationContent()
    }
}

extension CivilDay {
    static var today: CivilDay {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return CivilDay(year: parts.year ?? 2026, month: parts.month ?? 10, day: parts.day ?? 2)
    }
}
