#if os(macOS)
import AppKit
#endif
import SwiftUI
import ThaiLearnCore
import UniformTypeIdentifiers

struct AISettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var draft: [AICredential] = []
    @State private var notice = ""
    @State private var probes: [String: String] = [:]
    @State private var provider: AIProvider = .dashscope
    @State private var manualKey = ""
    @State private var manualBase = ""
    @State private var manualModel = ""
    @State private var manualRegion = ""
    @State private var chatID = ""
    @State private var speechID = ""
    @State private var transcriptionID = ""
    @State private var chatModel = ""
    @State private var speechModel = ""
    @State private var transcriptionModel = ""
    @State private var importingKeyFile = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
        CardShell {
            VStack(alignment: .leading, spacing: 14) {
                Text("AI 设置")
                    .font(.headline)
                Text("钥匙只放在系统钥匙串里，服务名是 WanLaNit.AI。不会写进 progress.json，也不会打到日志里。对话和出题默认通义千问（qwen-plus，可改）。朗读默认系统泰语。语音识别默认通义 qwen3-asr-flash，失败再用系统识别。")
                    .font(.callout)
                    .foregroundStyle(Ink.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Text("今天用了 \(model.progress.ai.usage.count(on: model.today)) / \(model.progress.ai.usage.dailyCap) 次。老师另外计 \(model.progress.tutor.requests(on: model.today)) / \(model.progress.tutor.requestCap) 次，约 \(model.progress.tutor.tokens(on: model.today)) tokens。")
                    .foregroundStyle(Ink.muted)
                Stepper(
                    "每天最多请求 \(model.progress.ai.usage.dailyCap) 次",
                    value: Binding(
                        get: { model.progress.ai.usage.dailyCap },
                        set: { model.setAIDailyCap($0) }
                    ),
                    in: 0...200
                )
                Text("0 表示不再请求云端。读缓存的朗读不计数。")
                    .font(.caption)
                    .foregroundStyle(Ink.muted)

                Button("从 APIKEY.md 导入") { beginImport() }
                    .buttonStyle(.borderedProminent)
                    .tint(Ink.lacquer)
                Text("Mac 会先指到 ~/keyoti/keyitems/pems/。iPhone 从「文件」里选同一份 APIKEY.md，也可以在下面手动填。")
                    .font(.caption)
                    .foregroundStyle(Ink.muted)

                if !notice.isEmpty {
                    Text(notice)
                        .font(.callout)
                        .foregroundStyle(Ink.ink)
                }

                ForEach(draft) { item in
                    credentialRow(item)
                }

                Text("手动添加")
                    .font(.headline)
                    .padding(.top, 4)
                Picker("服务", selection: $provider) {
                    ForEach(AIProvider.allCases, id: \.self) { item in
                        Text(item.chinese).tag(item)
                    }
                }
                SecureField("钥匙", text: $manualKey)
                    .textFieldStyle(.roundedBorder)
                TextField("Base URL，可空", text: $manualBase)
                    .textFieldStyle(.roundedBorder)
                TextField("模型，可空", text: $manualModel)
                    .textFieldStyle(.roundedBorder)
                TextField("区域，Azure 才需要", text: $manualRegion)
                    .textFieldStyle(.roundedBorder)
                Button("加入列表") { addManual() }
                    .disabled(manualKey.trimmingCharacters(in: .whitespacesAndNewlines).count < 8)

                Text("每项用来做什么")
                    .font(.headline)
                    .padding(.top, 4)
                assignmentPicker("对话、出题、批改", selection: $chatID, capability: .chat)
                TextField("对话模型，可空。通义默认 qwen-plus", text: $chatModel)
                    .textFieldStyle(.roundedBorder)
                assignmentPicker("AI 朗读", selection: $speechID, capability: .speech)
                Text("朗读默认仍是系统泰语。通义 Qwen-TTS 没有泰语；CosyVoice 的泰语只给复刻音色。要云端朗读再选 OpenAI、硅基流动、Azure 或 ElevenLabs。")
                    .font(.caption)
                    .foregroundStyle(Ink.muted)
                    .fixedSize(horizontal: false, vertical: true)
                TextField("朗读模型，可空", text: $speechModel)
                    .textFieldStyle(.roundedBorder)
                assignmentPicker("语音识别", selection: $transcriptionID, capability: .transcription)
                TextField("识别模型，可空。通义默认 qwen3-asr-flash", text: $transcriptionModel)
                    .textFieldStyle(.roundedBorder)
                VoiceSourceBar()
                Button("保存到钥匙串") { save() }
                    .buttonStyle(.borderedProminent)
                    .tint(Ink.leaf)
                if let saved = model.aiNotice, !saved.isEmpty {
                    Text(saved)
                        .font(.caption)
                        .foregroundStyle(Ink.muted)
                }
            }
        }
        TutorMemoryEditor()
        }
        .onAppear(perform: loadDraft)
        .fileImporter(isPresented: $importingKeyFile, allowedContentTypes: [.plainText, UTType(filenameExtension: "md") ?? .plainText]) { result in
            switch result {
            case .success(let url):
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                if let text = try? String(contentsOf: url, encoding: .utf8) {
                    applyImported(text)
                } else {
                    notice = "这个文件读不了。"
                }
            case .failure:
                notice = "没有选到文件。"
            }
        }
    }

    private func beginImport() {
        #if os(macOS)
        importFile()
        #else
        importingKeyFile = true
        #endif
    }

    private func credentialRow(_ item: AICredential) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(item.provider.chinese) · \(item.label)")
            Text(item.maskedKey)
                .font(.caption.monospaced())
            if !item.resolvedBaseURL.isEmpty {
                Text(item.resolvedBaseURL)
                    .font(.caption)
                    .foregroundStyle(Ink.muted)
                    .textSelection(.enabled)
            }
            if !item.models.isEmpty {
                Text(item.models.joined(separator: "、"))
                    .font(.caption)
                    .foregroundStyle(Ink.muted)
            }
            if let region = item.region, !region.isEmpty {
                Text("区域 \(region)")
                    .font(.caption)
                    .foregroundStyle(Ink.muted)
            }
            HStack {
                Button("测试连接") {
                    let modelName = item.models.first
                    probes[item.id] = "正在试…"
                    Task {
                        probes[item.id] = await model.probe(item, model: modelName)
                    }
                }
                Button("移除") { draft.removeAll { $0.id == item.id } }
            }
            if let result = probes[item.id] {
                Text(result)
                    .font(.caption)
                    .foregroundStyle(Ink.muted)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Ink.paper, in: RoundedRectangle(cornerRadius: 10))
    }

    private func assignmentPicker(_ title: String, selection: Binding<String>, capability: AICapability) -> some View {
        Picker(title, selection: selection) {
            Text(capability == .speech ? "自动（第一条能朗读的）" : "自动（优先通义千问）").tag("")
            ForEach(draft.filter { $0.provider.capabilities.contains(capability) }) { item in
                Text("\(item.provider.chinese) \(item.maskedKey)").tag(item.id)
            }
        }
    }

    private func loadDraft() {
        if draft.isEmpty { draft = model.credentials }
        chatID = model.assignments.chatID ?? ""
        speechID = model.assignments.speechID ?? ""
        transcriptionID = model.assignments.transcriptionID ?? ""
        chatModel = model.assignments.chatModel ?? ""
        speechModel = model.assignments.speechModel ?? ""
        transcriptionModel = model.assignments.transcriptionModel ?? ""
    }

    #if os(macOS)
    private func importFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("keyoti/keyitems/pems", isDirectory: true)
        var types: [UTType] = [.plainText]
        if let markdown = UTType(filenameExtension: "md") { types.append(markdown) }
        panel.allowedContentTypes = types
        panel.message = "选择 APIKEY.md。读到的钥匙只留在内存里，保存后进钥匙串。"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            notice = "这个文件读不了。"
            return
        }
        applyImported(text)
    }
    #endif

    private func applyImported(_ text: String) {
        let found = AIKeyParser.parse(text)
        guard !found.isEmpty else {
            notice = "没有认出钥匙。可以改用下面的手动添加。"
            return
        }
        draft = found
        let preferred = AIAssignments.preselected(from: found)
        chatID = preferred.chatID ?? ""
        transcriptionID = preferred.transcriptionID ?? ""
        if let modelName = preferred.chatModel { chatModel = modelName }
        if let modelName = preferred.transcriptionModel { transcriptionModel = modelName }
        if preferred.chatID != nil {
            notice = "认出 \(found.count) 条。对话和识别已预选通义千问，朗读仍用系统泰语。核对后保存到钥匙串。"
        } else {
            notice = "认出 \(found.count) 条。没有通义千问的钥匙，对话仍按「自动」选。核对后保存到钥匙串。"
        }
    }

    private func addManual() {
        let secret = manualKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard secret.count >= 8 else { return }
        let item = AICredential(
            id: "\(provider.rawValue)-\(UUID().uuidString.prefix(8))",
            provider: provider,
            label: provider.chinese,
            apiKey: secret,
            baseURL: manualBase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : manualBase.trimmingCharacters(in: .whitespacesAndNewlines),
            models: manualModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? [] : [manualModel.trimmingCharacters(in: .whitespacesAndNewlines)],
            region: manualRegion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : manualRegion.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        draft.append(item)
        manualKey = ""
        notice = "已加入列表。还没进钥匙串，要点保存。"
    }

    private func save() {
        model.saveAI(
            credentials: draft,
            assignments: AIAssignments(
                chatID: chatID.isEmpty ? nil : chatID,
                speechID: speechID.isEmpty ? nil : speechID,
                transcriptionID: transcriptionID.isEmpty ? nil : transcriptionID,
                chatModel: chatModel.isEmpty ? nil : chatModel,
                speechModel: speechModel.isEmpty ? nil : speechModel,
                transcriptionModel: transcriptionModel.isEmpty ? nil : transcriptionModel
            )
        )
    }
}
