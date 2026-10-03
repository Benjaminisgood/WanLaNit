import AppKit
import SwiftUI
import ThaiLearnCore
import UniformTypeIdentifiers

struct AISettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var draft: [AICredential] = []
    @State private var notice = ""
    @State private var probes: [String: String] = [:]
    @State private var provider: AIProvider = .openai
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

    var body: some View {
        CardShell {
            VStack(alignment: .leading, spacing: 14) {
                Text("AI 设置")
                    .font(.headline)
                Text("钥匙只放在系统钥匙串里，服务名是 WanLaNit.AI。不会写进 progress.json，也不会打到日志里。不设置也能学习：朗读用系统泰语，出题用本地题目，跟读用系统语音识别。")
                    .font(.callout)
                    .foregroundStyle(Ink.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Text("今天用了 \(model.progress.ai.usage.count(on: model.today)) / \(model.progress.ai.usage.dailyCap) 次")
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

                Button("从 APIKEY.md 导入") { importFile() }
                    .buttonStyle(.borderedProminent)
                    .tint(Ink.lacquer)
                Text("会打开文件选择，并先指到 ~/keyoti/keyitems/pems/。请自己选中那份文件。")
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
                TextField("对话模型，可空", text: $chatModel)
                    .textFieldStyle(.roundedBorder)
                assignmentPicker("AI 朗读", selection: $speechID, capability: .speech)
                TextField("朗读模型，可空", text: $speechModel)
                    .textFieldStyle(.roundedBorder)
                assignmentPicker("语音识别", selection: $transcriptionID, capability: .transcription)
                TextField("识别模型，可空", text: $transcriptionModel)
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
        .onAppear(perform: loadDraft)
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
            Text("自动（第一条合适的）").tag("")
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
        let found = AIKeyParser.parse(text)
        guard !found.isEmpty else {
            notice = "没有认出钥匙。可以改用下面的手动添加。"
            return
        }
        draft = found
        notice = "认出 \(found.count) 条。核对打码后的钥匙，选好用途，再保存到钥匙串。"
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
