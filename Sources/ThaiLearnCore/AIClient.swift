import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct AIChatMessage: Codable, Equatable, Sendable {
    public var role: String
    public var content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }

    public static func system(_ text: String) -> AIChatMessage { AIChatMessage(role: "system", content: text) }
    public static func user(_ text: String) -> AIChatMessage { AIChatMessage(role: "user", content: text) }
}

public protocol ChatModel {
    func complete(messages: [AIChatMessage], jsonObject: Bool) async throws -> String
}

public protocol SpeechSynthesizer {
    func synthesize(text: String, speed: Double) async throws -> Data
}

public protocol SpeechRecognizer {
    func transcribe(audioWAV: Data) async throws -> String
}

public struct AIHTTPResponse: Equatable, Sendable {
    public var status: Int
    public var data: Data

    public init(status: Int, data: Data) {
        self.status = status
        self.data = data
    }

    public var text: String { String(data: data, encoding: .utf8) ?? "" }
}

public protocol AITransport {
    func send(_ request: URLRequest) async throws -> AIHTTPResponse
}

public final class URLSessionAITransport: AITransport {
    public let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(_ request: URLRequest) async throws -> AIHTTPResponse {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AIClientError.http(status: 0, message: "没有 HTTP 响应")
        }
        return AIHTTPResponse(status: http.statusCode, data: data)
    }
}

public enum AIClientError: Error, Equatable, CustomStringConvertible {
    case badURL
    case http(status: Int, message: String)
    case empty
    case capped
    case decode

    public var description: String {
        switch self {
        case .badURL: return "地址不对"
        case .http(let status, let message): return "连接失败：HTTP \(status) \(message)"
        case .empty: return "服务没有返回内容"
        case .capped: return "今天的 AI 次数用完了"
        case .decode: return "返回的内容不是约定的格式"
        }
    }
}

public final class OpenAICompatibleClient: ChatModel, SpeechSynthesizer, SpeechRecognizer {
    public let baseURL: URL
    public let apiKey: String
    public let transport: AITransport
    public var chatModel: String
    public var speechModel: String
    public var speechVoice: String
    public var transcriptionModel: String
    public var extraHeaders: [String: String]

    public init(
        baseURL: URL,
        apiKey: String,
        transport: AITransport,
        chatModel: String,
        speechModel: String = "tts-1",
        speechVoice: String = "nova",
        transcriptionModel: String = "whisper-1",
        extraHeaders: [String: String] = [:]
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.transport = transport
        self.chatModel = chatModel
        self.speechModel = speechModel
        self.speechVoice = speechVoice
        self.transcriptionModel = transcriptionModel
        self.extraHeaders = extraHeaders
    }

    public func complete(messages: [AIChatMessage], jsonObject: Bool) async throws -> String {
        var payload: [String: Any] = [
            "model": chatModel,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "temperature": 0.4
        ]
        if jsonObject { payload["response_format"] = ["type": "json_object"] }
        let response = try await post(path: "chat/completions", json: payload)
        if jsonObject, !(200..<300).contains(response.status) {
            payload.removeValue(forKey: "response_format")
            let retry = try await post(path: "chat/completions", json: payload)
            return try chatText(retry)
        }
        return try chatText(response)
    }

    public func synthesize(text: String, speed: Double) async throws -> Data {
        let body: [String: Any] = [
            "model": speechModel,
            "input": text,
            "voice": speechVoice,
            "speed": min(4, max(0.25, speed)),
            "response_format": "mp3"
        ]
        let response = try await post(path: "audio/speech", json: body)
        try throwIfNeeded(response)
        guard !response.data.isEmpty else { throw AIClientError.empty }
        return response.data
    }

    public func transcribe(audioWAV: Data) async throws -> String {
        let boundary = "wanlanit-\(UUID().uuidString)"
        var body = Data()
        func append(_ string: String) { body.append(Data(string.utf8)) }
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"speech.wav\"\r\n")
        append("Content-Type: audio/wav\r\n\r\n")
        body.append(audioWAV)
        append("\r\n--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"model\"\r\n\r\n\(transcriptionModel)\r\n")
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"language\"\r\n\r\nth\r\n")
        append("--\(boundary)--\r\n")
        var request = try makeRequest(path: "audio/transcriptions")
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        let response = try await transport.send(request)
        try throwIfNeeded(response)
        guard let object = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any],
              let text = object["text"] as? String,
              !text.isEmpty
        else { throw AIClientError.empty }
        return text
    }

    public func probe() async throws -> String {
        let listed = try await get(path: "models")
        if (200..<300).contains(listed.status) { return "连接成功" }
        let reply = try await complete(messages: [.user("Reply with the single word ok.")], jsonObject: false)
        return reply.isEmpty ? "连接成功" : "连接成功"
    }

    private func chatText(_ response: AIHTTPResponse) throws -> String {
        try throwIfNeeded(response)
        guard let object = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any],
              let choices = object["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any]
        else { throw AIClientError.decode }
        if let content = message["content"] as? String {
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { throw AIClientError.empty }
            return trimmed
        }
        if let parts = message["content"] as? [[String: Any]] {
            let text = parts.compactMap { $0["text"] as? String }.joined()
            guard !text.isEmpty else { throw AIClientError.empty }
            return text
        }
        throw AIClientError.empty
    }

    private func post(path: String, json: [String: Any]) async throws -> AIHTTPResponse {
        var request = try makeRequest(path: path)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: json)
        return try await transport.send(request)
    }

    private func get(path: String) async throws -> AIHTTPResponse {
        var request = try makeRequest(path: path)
        request.httpMethod = "GET"
        return try await transport.send(request)
    }

    private func makeRequest(path: String) throws -> URLRequest {
        let root = baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let suffix = path.hasPrefix("/") ? String(path.dropFirst()) : path
        guard let url = URL(string: root + "/" + suffix) else { throw AIClientError.badURL }
        var request = URLRequest(url: url)
        request.timeoutInterval = 45
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        for (field, value) in extraHeaders {
            request.setValue(value, forHTTPHeaderField: field)
        }
        return request
    }

    private func throwIfNeeded(_ response: AIHTTPResponse) throws {
        guard (200..<300).contains(response.status) else {
            throw AIClientError.http(status: response.status, message: AIKeyMask.redact(response.text, secrets: [apiKey]))
        }
    }
}

public final class AnthropicChatClient: ChatModel {
    public let apiKey: String
    public let model: String
    public let transport: AITransport

    public init(apiKey: String, model: String, transport: AITransport) {
        self.apiKey = apiKey
        self.model = model
        self.transport = transport
    }

    public func complete(messages: [AIChatMessage], jsonObject: Bool) async throws -> String {
        let system = messages.filter { $0.role == "system" }.map(\.content).joined(separator: "\n")
        let turns = messages.filter { $0.role != "system" }.map { ["role": $0.role == "assistant" ? "assistant" : "user", "content": $0.content] }
        var payload: [String: Any] = [
            "model": model,
            "max_tokens": jsonObject ? 1200 : 500,
            "messages": turns.isEmpty ? [["role": "user", "content": "ok"]] : turns
        ]
        if !system.isEmpty { payload["system"] = system }
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else { throw AIClientError.badURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let response = try await transport.send(request)
        guard (200..<300).contains(response.status) else {
            throw AIClientError.http(status: response.status, message: AIKeyMask.redact(response.text, secrets: [apiKey]))
        }
        guard let object = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any],
              let content = object["content"] as? [[String: Any]]
        else { throw AIClientError.decode }
        let text = content.compactMap { $0["text"] as? String }.joined()
        guard !text.isEmpty else { throw AIClientError.empty }
        return text
    }
}

public final class ElevenLabsSpeech: SpeechSynthesizer {
    public let apiKey: String
    public let voiceID: String
    public let model: String
    public let transport: AITransport

    public init(apiKey: String, voiceID: String, model: String, transport: AITransport) {
        self.apiKey = apiKey
        self.voiceID = voiceID
        self.model = model
        self.transport = transport
    }

    public func synthesize(text: String, speed: Double) async throws -> Data {
        guard let url = URL(string: "https://api.elevenlabs.io/v1/text-to-speech/\(voiceID)") else { throw AIClientError.badURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")
        let body: [String: Any] = ["text": text, "model_id": model]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let response = try await transport.send(request)
        guard (200..<300).contains(response.status) else {
            throw AIClientError.http(status: response.status, message: AIKeyMask.redact(response.text, secrets: [apiKey]))
        }
        guard !response.data.isEmpty else { throw AIClientError.empty }
        return response.data
    }
}

public final class AzureSpeech: SpeechSynthesizer {
    public let apiKey: String
    public let region: String
    public let voice: String
    public let transport: AITransport

    public init(apiKey: String, region: String, voice: String, transport: AITransport) {
        self.apiKey = apiKey
        self.region = region
        self.voice = voice
        self.transport = transport
    }

    public func synthesize(text: String, speed: Double) async throws -> Data {
        guard let url = URL(string: "https://\(region).tts.speech.microsoft.com/cognitiveservices/v1") else {
            throw AIClientError.badURL
        }
        let escaped = text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        let rate = speed < 0.85 ? "slow" : (speed > 1.15 ? "fast" : "medium")
        let ssml = """
        <speak version='1.0' xml:lang='th-TH'><voice xml:lang='th-TH' name='\(voice)'><prosody rate='\(rate)'>\(escaped)</prosody></voice></speak>
        """
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue(apiKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        request.setValue("application/ssml+xml", forHTTPHeaderField: "Content-Type")
        request.setValue("audio-16khz-128kbitrate-mono-mp3", forHTTPHeaderField: "X-Microsoft-OutputFormat")
        request.httpBody = Data(ssml.utf8)
        let response = try await transport.send(request)
        guard (200..<300).contains(response.status) else {
            throw AIClientError.http(status: response.status, message: AIKeyMask.redact(response.text, secrets: [apiKey]))
        }
        guard !response.data.isEmpty else { throw AIClientError.empty }
        return response.data
    }
}

public enum AIClients {
    public static func transport(_ session: URLSession = .shared) -> AITransport {
        URLSessionAITransport(session: session)
    }

    public static func chat(_ credential: AICredential, model: String, transport: AITransport) throws -> ChatModel {
        if credential.provider == .anthropic {
            return AnthropicChatClient(apiKey: credential.apiKey, model: model, transport: transport)
        }
        guard let url = URL(string: credential.resolvedBaseURL), !credential.resolvedBaseURL.isEmpty else {
            throw AIClientError.badURL
        }
        var headers: [String: String] = [:]
        if credential.provider == .gemini {
            headers["x-goog-api-key"] = credential.apiKey
        }
        return OpenAICompatibleClient(
            baseURL: url,
            apiKey: credential.apiKey,
            transport: transport,
            chatModel: model,
            extraHeaders: headers
        )
    }

    public static func speech(
        _ credential: AICredential,
        model: String,
        voice: String,
        transport: AITransport
    ) throws -> SpeechSynthesizer {
        switch credential.provider {
        case .elevenlabs:
            return ElevenLabsSpeech(apiKey: credential.apiKey, voiceID: voice, model: model, transport: transport)
        case .azure:
            let region = credential.region ?? "southeastasia"
            return AzureSpeech(apiKey: credential.apiKey, region: region, voice: voice.isEmpty ? model : voice, transport: transport)
        default:
            guard let url = URL(string: credential.resolvedBaseURL), !credential.resolvedBaseURL.isEmpty else {
                throw AIClientError.badURL
            }
            return OpenAICompatibleClient(
                baseURL: url,
                apiKey: credential.apiKey,
                transport: transport,
                chatModel: credential.model(for: .chat, override: nil),
                speechModel: model,
                speechVoice: voice
            )
        }
    }

    public static func recognizer(_ credential: AICredential, model: String, transport: AITransport) throws -> SpeechRecognizer {
        guard credential.provider.capabilities.contains(.transcription) else { throw AIClientError.badURL }
        guard let url = URL(string: credential.resolvedBaseURL), !credential.resolvedBaseURL.isEmpty else {
            throw AIClientError.badURL
        }
        return OpenAICompatibleClient(
            baseURL: url,
            apiKey: credential.apiKey,
            transport: transport,
            chatModel: credential.model(for: .chat, override: nil),
            transcriptionModel: model
        )
    }

    public static func probe(_ credential: AICredential, model: String?, transport: AITransport) async -> String {
        do {
            switch credential.provider {
            case .elevenlabs:
                guard let url = URL(string: "https://api.elevenlabs.io/v1/user") else { return AIClientError.badURL.description }
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.setValue(credential.apiKey, forHTTPHeaderField: "xi-api-key")
                let response = try await transport.send(request)
                guard (200..<300).contains(response.status) else {
                    throw AIClientError.http(status: response.status, message: AIKeyMask.redact(response.text, secrets: [credential.apiKey]))
                }
                return "连接成功"
            case .azure:
                let region = credential.region ?? "southeastasia"
                guard let url = URL(string: "https://\(region).tts.speech.microsoft.com/cognitiveservices/voices/list") else {
                    return AIClientError.badURL.description
                }
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.setValue(credential.apiKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
                let response = try await transport.send(request)
                guard (200..<300).contains(response.status) else {
                    throw AIClientError.http(status: response.status, message: AIKeyMask.redact(response.text, secrets: [credential.apiKey]))
                }
                return "连接成功"
            case .anthropic:
                let client = AnthropicChatClient(
                    apiKey: credential.apiKey,
                    model: model ?? credential.model(for: .chat, override: nil),
                    transport: transport
                )
                _ = try await client.complete(messages: [.user("Reply with ok.")], jsonObject: false)
                return "连接成功"
            default:
                guard let url = URL(string: credential.resolvedBaseURL), !credential.resolvedBaseURL.isEmpty else {
                    return AIClientError.badURL.description
                }
                let client = OpenAICompatibleClient(
                    baseURL: url,
                    apiKey: credential.apiKey,
                    transport: transport,
                    chatModel: model ?? credential.model(for: .chat, override: nil),
                    extraHeaders: credential.provider == .gemini ? ["x-goog-api-key": credential.apiKey] : [:]
                )
                return try await client.probe()
            }
        } catch let error as AIClientError {
            return error.description
        } catch {
            return "连接失败"
        }
    }
}

public enum WAVAudio {
    public static func pcm16(samples: [Float], sampleRate: Double) -> Data {
        var data = Data()
        let rate = UInt32(max(sampleRate, 8000))
        let bytes = UInt32(samples.count * 2)
        data.append(contentsOf: [0x52, 0x49, 0x46, 0x46])
        data.append(uint32(36 + bytes))
        data.append(contentsOf: [0x57, 0x41, 0x56, 0x45, 0x66, 0x6d, 0x74, 0x20])
        data.append(uint32(16))
        data.append(uint16(1))
        data.append(uint16(1))
        data.append(uint32(rate))
        data.append(uint32(rate * 2))
        data.append(uint16(2))
        data.append(uint16(16))
        data.append(contentsOf: [0x64, 0x61, 0x74, 0x61])
        data.append(uint32(bytes))
        for sample in samples {
            let clamped = max(-1, min(1, sample))
            let unsigned = UInt16(bitPattern: Int16(clamped * 32767))
            data.append(UInt8(unsigned & 0xff))
            data.append(UInt8(unsigned >> 8))
        }
        return data
    }

    private static func uint32(_ value: UInt32) -> Data {
        var little = value.littleEndian
        return withUnsafeBytes(of: &little) { Data($0) }
    }

    private static func uint16(_ value: UInt16) -> Data {
        var little = value.littleEndian
        return withUnsafeBytes(of: &little) { Data($0) }
    }
}
