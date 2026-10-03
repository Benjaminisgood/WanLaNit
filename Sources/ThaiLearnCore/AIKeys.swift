import Foundation

public enum AICapability: String, Codable, CaseIterable, Sendable {
    case chat
    case speech
    case transcription

    public var chinese: String {
        switch self {
        case .chat: return "对话和出题"
        case .speech: return "朗读"
        case .transcription: return "语音识别"
        }
    }
}

public enum AIProvider: String, Codable, CaseIterable, Hashable, Sendable {
    case openai
    case gemini
    case deepseek
    case dashscope
    case zhipu
    case moonshot
    case anthropic
    case openrouter
    case siliconflow
    case azure
    case elevenlabs
    case custom

    public var chinese: String {
        switch self {
        case .openai: return "OpenAI"
        case .gemini: return "Gemini"
        case .deepseek: return "DeepSeek"
        case .dashscope: return "通义千问"
        case .zhipu: return "智谱"
        case .moonshot: return "Kimi"
        case .anthropic: return "Anthropic"
        case .openrouter: return "OpenRouter"
        case .siliconflow: return "硅基流动"
        case .azure: return "Azure 语音"
        case .elevenlabs: return "ElevenLabs"
        case .custom: return "自定义"
        }
    }

    public var capabilities: [AICapability] {
        switch self {
        case .openai, .custom:
            return [.chat, .speech, .transcription]
        case .siliconflow:
            return [.chat, .speech]
        case .azure, .elevenlabs:
            return [.speech]
        case .gemini, .deepseek, .dashscope, .zhipu, .moonshot, .anthropic, .openrouter:
            return [.chat]
        }
    }

    public var defaultBaseURL: String {
        switch self {
        case .openai: return "https://api.openai.com/v1"
        case .gemini: return "https://generativelanguage.googleapis.com/v1beta/openai"
        case .deepseek: return "https://api.deepseek.com"
        case .dashscope: return "https://dashscope.aliyuncs.com/compatible-mode/v1"
        case .zhipu: return "https://open.bigmodel.cn/api/paas/v4"
        case .moonshot: return "https://api.moonshot.cn/v1"
        case .anthropic: return "https://api.anthropic.com"
        case .openrouter: return "https://openrouter.ai/api/v1"
        case .siliconflow: return "https://api.siliconflow.cn/v1"
        case .azure: return ""
        case .elevenlabs: return "https://api.elevenlabs.io"
        case .custom: return ""
        }
    }

    public var defaultChatModel: String {
        switch self {
        case .openai: return "gpt-4o-mini"
        case .gemini: return "gemini-2.0-flash"
        case .deepseek: return "deepseek-chat"
        case .dashscope: return "qwen-plus"
        case .zhipu: return "glm-4-flash"
        case .moonshot: return "moonshot-v1-8k"
        case .anthropic: return "claude-3-5-haiku-latest"
        case .openrouter: return "openai/gpt-4o-mini"
        case .siliconflow: return "Qwen/Qwen2.5-7B-Instruct"
        case .azure, .elevenlabs: return ""
        case .custom: return ""
        }
    }

    public var defaultSpeechModel: String {
        switch self {
        case .openai: return "tts-1"
        case .siliconflow: return "FunAudioLLM/CosyVoice2-0.5B"
        case .elevenlabs: return "eleven_multilingual_v2"
        case .azure: return "th-TH-PremwadeeNeural"
        case .custom: return "tts-1"
        default: return ""
        }
    }

    public var defaultTranscriptionModel: String {
        switch self {
        case .openai, .custom: return "whisper-1"
        default: return ""
        }
    }

    public var voices: [String] {
        switch self {
        case .openai, .custom:
            return ["alloy", "echo", "fable", "onyx", "nova", "shimmer"]
        case .azure:
            return ["th-TH-PremwadeeNeural", "th-TH-NiwatNeural"]
        case .elevenlabs:
            return ["21m00Tcm4TlvDq8ikWAM"]
        case .siliconflow:
            return ["alex", "anna"]
        default:
            return []
        }
    }

    public static func named(_ raw: String) -> AIProvider? {
        let name = raw.lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "*", with: "")
        switch name {
        case "openai": return .openai
        case "gemini", "google", "googleai": return .gemini
        case "deepseek": return .deepseek
        case "dashscope", "qwen", "tongyi", "aliyun": return .dashscope
        case "zhipu", "zhipuai", "glm", "bigmodel": return .zhipu
        case "moonshot", "kimi": return .moonshot
        case "anthropic", "claude": return .anthropic
        case "openrouter": return .openrouter
        case "siliconflow", "silicon", "guiji": return .siliconflow
        case "azure", "azurespeech", "microsoft": return .azure
        case "elevenlabs", "eleven", "11labs": return .elevenlabs
        case "custom": return .custom
        default: return nil
        }
    }
}

public struct AICredential: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var provider: AIProvider
    public var label: String
    public var apiKey: String
    public var baseURL: String?
    public var models: [String]
    public var region: String?

    public init(
        id: String,
        provider: AIProvider,
        label: String,
        apiKey: String,
        baseURL: String? = nil,
        models: [String] = [],
        region: String? = nil
    ) {
        self.id = id
        self.provider = provider
        self.label = label
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.models = models
        self.region = region
    }

    public var maskedKey: String { AIKeyMask.mask(apiKey) }

    public var resolvedBaseURL: String {
        let trimmed = baseURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty { return trimmed }
        if provider == .azure, let region, !region.isEmpty {
            return "https://\(region).tts.speech.microsoft.com"
        }
        return provider.defaultBaseURL
    }

    public func model(for capability: AICapability, override: String?) -> String {
        let chosen = override?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !chosen.isEmpty { return chosen }
        if let first = models.first, !first.isEmpty { return first }
        switch capability {
        case .chat: return provider.defaultChatModel
        case .speech: return provider.defaultSpeechModel
        case .transcription: return provider.defaultTranscriptionModel
        }
    }
}

public struct AIAssignments: Codable, Equatable, Sendable {
    public var chatID: String?
    public var speechID: String?
    public var transcriptionID: String?
    public var chatModel: String?
    public var speechModel: String?
    public var transcriptionModel: String?

    public init(
        chatID: String? = nil,
        speechID: String? = nil,
        transcriptionID: String? = nil,
        chatModel: String? = nil,
        speechModel: String? = nil,
        transcriptionModel: String? = nil
    ) {
        self.chatID = chatID
        self.speechID = speechID
        self.transcriptionID = transcriptionID
        self.chatModel = chatModel
        self.speechModel = speechModel
        self.transcriptionModel = transcriptionModel
    }
}

public enum AIKeyMask {
    /// Shows a short prefix and the last four characters. The middle is never returned.
    public static func mask(_ key: String) -> String {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 8 else { return "••••" }
        let heads = ["sk-ant-", "sk-or-", "sk-", "AIza"]
        let head = heads.first { trimmed.hasPrefix($0) } ?? String(trimmed.prefix(4))
        return "\(head)…\(trimmed.suffix(4))"
    }

    public static func redact(_ text: String, secrets: [String]) -> String {
        var result = text
        for secret in secrets where secret.count >= 8 {
            result = result.replacingOccurrences(of: secret, with: mask(secret))
        }
        if result.count > 180 {
            result = String(result.prefix(180))
        }
        return result
    }
}

public enum AICacheKey {
    public static func digest(text: String, voice: String, model: String, speed: Double) -> String {
        let rate = String(format: "%.2f", speed)
        return sha256("\(model)\n\(voice)\n\(rate)\n\(text)")
    }

    public static func sha256(_ text: String) -> String {
        hex(sha256(Array(text.utf8)))
    }

    private static func hex(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02x", $0) }.joined()
    }

    private static func sha256(_ message: [UInt8]) -> [UInt8] {
        var hash: [UInt32] = [
            0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
            0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
        ]
        let k: [UInt32] = [
            0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
            0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
            0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
            0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
            0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
            0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
            0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
            0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
        ]
        var bytes = message
        let bitCount = UInt64(message.count) * 8
        bytes.append(0x80)
        while bytes.count % 64 != 56 { bytes.append(0) }
        for shift in stride(from: 56, through: 0, by: -8) {
            bytes.append(UInt8((bitCount >> UInt64(shift)) & 0xff))
        }
        func rotr(_ x: UInt32, _ n: UInt32) -> UInt32 { (x >> n) | (x << (32 - n)) }
        var offset = 0
        while offset < bytes.count {
            var w = [UInt32](repeating: 0, count: 64)
            for index in 0..<16 {
                let start = offset + index * 4
                w[index] = (UInt32(bytes[start]) << 24) | (UInt32(bytes[start + 1]) << 16)
                    | (UInt32(bytes[start + 2]) << 8) | UInt32(bytes[start + 3])
            }
            for index in 16..<64 {
                let s0 = rotr(w[index - 15], 7) ^ rotr(w[index - 15], 18) ^ (w[index - 15] >> 3)
                let s1 = rotr(w[index - 2], 17) ^ rotr(w[index - 2], 19) ^ (w[index - 2] >> 10)
                w[index] = w[index - 16] &+ s0 &+ w[index - 7] &+ s1
            }
            var a = hash[0], b = hash[1], c = hash[2], d = hash[3]
            var e = hash[4], f = hash[5], g = hash[6], h = hash[7]
            for index in 0..<64 {
                let s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)
                let ch = (e & f) ^ (~e & g)
                let temp1 = h &+ s1 &+ ch &+ k[index] &+ w[index]
                let s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)
                let maj = (a & b) ^ (a & c) ^ (b & c)
                let temp2 = s0 &+ maj
                h = g
                g = f
                f = e
                e = d &+ temp1
                d = c
                c = b
                b = a
                a = temp1 &+ temp2
            }
            hash[0] = hash[0] &+ a
            hash[1] = hash[1] &+ b
            hash[2] = hash[2] &+ c
            hash[3] = hash[3] &+ d
            hash[4] = hash[4] &+ e
            hash[5] = hash[5] &+ f
            hash[6] = hash[6] &+ g
            hash[7] = hash[7] &+ h
            offset += 64
        }
        var out: [UInt8] = []
        for word in hash {
            out.append(UInt8((word >> 24) & 0xff))
            out.append(UInt8((word >> 16) & 0xff))
            out.append(UInt8((word >> 8) & 0xff))
            out.append(UInt8(word & 0xff))
        }
        return out
    }
}

public enum AIKeyParser {
    public static func parse(_ text: String) -> [AICredential] {
        var items: [AICredential] = []
        var section: AIProvider?
        var pendingBase: [AIProvider: String] = [:]
        var pendingModels: [AIProvider: [String]] = [:]
        var pendingRegion: [AIProvider: String] = [:]
        var looseBase: String?
        var looseModels: [String] = []
        var looseRegion: String?

        func remember(provider: AIProvider?, base: String?, models: [String], region: String?) {
            if let provider {
                if let base { pendingBase[provider] = base }
                if !models.isEmpty { pendingModels[provider, default: []].append(contentsOf: models) }
                if let region { pendingRegion[provider] = region }
                if let index = items.lastIndex(where: { $0.provider == provider }) {
                    if let base, items[index].baseURL == nil { items[index].baseURL = base }
                    for model in models where !items[index].models.contains(model) {
                        items[index].models.append(model)
                    }
                    if let region { items[index].region = region }
                }
            } else {
                if let base { looseBase = base }
                looseModels.append(contentsOf: models)
                if let region { looseRegion = region }
            }
        }

        func add(provider: AIProvider, label: String, key: String) {
            let secret = clean(key)
            guard looksLikeKey(secret) || secret.count >= 16 else { return }
            if items.contains(where: { $0.provider == provider && $0.apiKey == secret }) { return }
            var item = AICredential(
                id: "",
                provider: provider,
                label: label.isEmpty ? provider.chinese : label,
                apiKey: secret,
                baseURL: pendingBase[provider] ?? looseBase,
                models: pendingModels[provider] ?? looseModels,
                region: pendingRegion[provider] ?? looseRegion
            )
            if item.models.isEmpty, !provider.defaultChatModel.isEmpty, provider.capabilities.contains(.chat) {
                item.models = [provider.defaultChatModel]
            }
            items.append(item)
            looseBase = nil
            looseModels = []
            looseRegion = nil
        }

        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if line.hasPrefix("```") { continue }
            if line.hasPrefix("#") {
                let title = line.drop { $0 == "#" || $0 == " " }
                if let provider = AIProvider.named(String(title.prefix { !$0.isWhitespace })) ?? AIProvider.named(String(title)) {
                    section = provider
                }
                continue
            }
            guard let pair = splitAssignment(line) else {
                let token = clean(line)
                if looksLikeKey(token), let provider = providerForKey(token, section: section) {
                    add(provider: provider, label: provider.chinese, key: token)
                }
                continue
            }
            let name = pair.name
            let value = clean(pair.value)
            let env = name.uppercased().replacingOccurrences(of: " ", with: "_")
            if env == "AZURE_SPEECH_REGION" || env == "AZURE_REGION" || env == "SPEECH_REGION" || name.lowercased() == "region" {
                remember(provider: section ?? .azure, base: nil, models: [], region: value)
                continue
            }
            if isBaseName(name) {
                remember(provider: providerHint(in: name) ?? section, base: value, models: [], region: nil)
                continue
            }
            if isModelName(name) {
                let models = value.split { $0 == "," || $0 == " " }.map { clean(String($0)) }.filter { !$0.isEmpty }
                remember(provider: providerHint(in: name) ?? section, base: nil, models: models, region: nil)
                continue
            }
            if let provider = provider(forEnv: env) {
                add(provider: provider, label: provider.chinese, key: value)
                continue
            }
            if let provider = AIProvider.named(name) {
                if looksLikeKey(value) || value.count >= 16 {
                    add(provider: provider, label: provider.chinese, key: value)
                }
                continue
            }
            if isKeyName(name) {
                let provider = section ?? providerForKey(value, section: nil) ?? .custom
                add(provider: provider, label: provider.chinese, key: value)
            }
        }
        for index in items.indices {
            items[index].id = "\(items[index].provider.rawValue)-\(index + 1)"
        }
        return items
    }

    private static func provider(forEnv name: String) -> AIProvider? {
        switch name {
        case "OPENAI_API_KEY": return .openai
        case "GEMINI_API_KEY", "GOOGLE_API_KEY": return .gemini
        case "DEEPSEEK_API_KEY": return .deepseek
        case "DASHSCOPE_API_KEY", "QWEN_API_KEY": return .dashscope
        case "ZHIPU_API_KEY", "ZHIPUAI_API_KEY", "GLM_API_KEY": return .zhipu
        case "MOONSHOT_API_KEY", "KIMI_API_KEY": return .moonshot
        case "ANTHROPIC_API_KEY": return .anthropic
        case "OPENROUTER_API_KEY": return .openrouter
        case "SILICONFLOW_API_KEY", "SILICONFLOW_KEY": return .siliconflow
        case "AZURE_SPEECH_KEY": return .azure
        case "ELEVENLABS_API_KEY", "XI_API_KEY": return .elevenlabs
        default: return nil
        }
    }

    private static func providerHint(in name: String) -> AIProvider? {
        let lower = name.lowercased()
        if lower.contains("openai") { return .openai }
        if lower.contains("gemini") || lower.contains("google") { return .gemini }
        if lower.contains("azure") { return .azure }
        return nil
    }

    private static func providerForKey(_ key: String, section: AIProvider?) -> AIProvider? {
        if key.hasPrefix("sk-ant-") { return .anthropic }
        if key.hasPrefix("sk-or-") { return .openrouter }
        if key.hasPrefix("AIza") { return .gemini }
        if key.hasPrefix("sk-") { return section ?? .openai }
        return section
    }

    private static func isBaseName(_ name: String) -> Bool {
        let lower = name.lowercased().replacingOccurrences(of: "-", with: "_")
        return lower == "base_url" || lower == "baseurl" || lower == "api_base" || lower.hasSuffix("_base_url")
    }

    private static func isModelName(_ name: String) -> Bool {
        let lower = name.lowercased()
        return lower == "model" || lower == "models" || lower.hasSuffix("_model")
    }

    private static func isKeyName(_ name: String) -> Bool {
        let lower = name.lowercased().replacingOccurrences(of: "-", with: "_")
        return lower == "api_key" || lower == "apikey" || lower == "key" || lower == "token" || lower.hasSuffix("_api_key")
    }

    private static func looksLikeKey(_ value: String) -> Bool {
        if value.hasPrefix("http://") || value.hasPrefix("https://") { return false }
        if value.contains(" ") || value.count < 12 { return false }
        if value.hasPrefix("sk-") || value.hasPrefix("AIza") { return true }
        return value.count >= 20 && value.allSatisfy { $0.isLetter || $0.isNumber || "-_.".contains($0) }
    }

    private static func clean(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let first = value.first, "\"'`".contains(first) {
            value.removeFirst()
            if value.last == first { value.removeLast() }
        }
        if let range = value.range(of: " #") {
            value = String(value[..<range.lowerBound])
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private struct Assignment {
        var name: String
        var value: String
    }

    private static func splitAssignment(_ line: String) -> Assignment? {
        var text = line
        if text.hasPrefix("- ") || text.hasPrefix("* ") { text.removeFirst(2) }
        text = text.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("export ") { text.removeFirst("export ".count) }
        text = text.replacingOccurrences(of: "**", with: "")
        let separators: [Character] = ["=", ":", "："]
        guard let index = text.firstIndex(where: { separators.contains($0) }) else { return nil }
        let name = text[..<index].trimmingCharacters(in: .whitespaces)
        let value = text[text.index(after: index)...].trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !value.isEmpty else { return nil }
        guard !name.contains(" ") || AIProvider.named(name) != nil else { return nil }
        return Assignment(name: name, value: value)
    }
}
