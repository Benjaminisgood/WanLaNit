import XCTest
import ThaiLearnCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class AITests: XCTestCase {
    func testParserReadsEnvMarkdownFencesAndPrefixes() {
        let text = """
        # 说明
        OPENAI_API_KEY=sk-test-fixture-not-a-real-key-0001
        export GEMINI_API_KEY="AIza-gemini-test-5678"
        DEEPSEEK_API_KEY=sk-deepseek-test-9012
        DASHSCOPE_API_KEY=sk-dashscope-test-3456
        ZHIPU_API_KEY=zhipu.test.key.7890abcd
        MOONSHOT_API_KEY=sk-moonshot-test-abcd
        ANTHROPIC_API_KEY=sk-ant-test-anthropic-efgh
        OPENROUTER_API_KEY=sk-or-test-router-ijkl
        SILICONFLOW_API_KEY=sk-silicon-test-mnopqr
        AZURE_SPEECH_KEY=azurekeytest1234567890
        AZURE_SPEECH_REGION=southeastasia
        ELEVENLABS_API_KEY=eleven-test-key-qrstuv

        - **OpenAI**: sk-list-openai-aaaa1111

        # DeepSeek
        base_url: https://example.invalid/v1
        model: deepseek-chat
        api_key: sk-heading-deepseek-2222

        ```env
        OPENAI_BASE_URL=https://fenced.invalid/v1
        OPENAI_MODEL=gpt-4o-mini
        OPENAI_API_KEY=sk-fenced-openai-cccc3333
        ```

        key: sk-loose-custom-dddd4444
        AIzaSYTESTONLY0001234abcd
        """
        let found = AIKeyParser.parse(text)
        let providers = Set(found.map(\.provider))
        XCTAssertTrue(providers.isSuperset(of: [
            .openai, .gemini, .deepseek, .dashscope, .zhipu, .moonshot,
            .anthropic, .openrouter, .siliconflow, .azure, .elevenlabs
        ]))
        let azure = found.first { $0.provider == .azure }
        XCTAssertEqual(azure?.region, "southeastasia")
        let headed = found.first { $0.apiKey == "sk-heading-deepseek-2222" }
        XCTAssertEqual(headed?.baseURL, "https://example.invalid/v1")
        XCTAssertTrue(headed?.models.contains("deepseek-chat") == true)
        let fenced = found.first { $0.apiKey == "sk-fenced-openai-cccc3333" }
        XCTAssertEqual(fenced?.provider, .openai)
        XCTAssertEqual(fenced?.baseURL, "https://fenced.invalid/v1")
        XCTAssertTrue(fenced?.models.contains("gpt-4o-mini") == true)
        XCTAssertEqual(found.first { $0.apiKey.hasPrefix("AIzaSY") }?.provider, .gemini)
        XCTAssertTrue(found.allSatisfy { !$0.id.isEmpty })
        let encoded = String(data: (try? JSONEncoder().encode(found)) ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(encoded.contains("sk-test-fixture"))
        XCTAssertFalse(AIKeyMask.mask("sk-test-fixture-not-a-real-key-0001").contains("fixture"))
    }

    func testMaskingHidesTheMiddle() {
        XCTAssertEqual(AIKeyMask.mask("sk-test-fixture-not-a-real-key-0001"), "sk-…0001")
        XCTAssertEqual(AIKeyMask.mask("sk-ant-test-anthropic-efgh"), "sk-ant-…efgh")
        XCTAssertEqual(AIKeyMask.mask("sk-or-test-router-ijkl"), "sk-or-…ijkl")
        XCTAssertEqual(AIKeyMask.mask("AIza-gemini-test-5678"), "AIza…5678")
        XCTAssertEqual(AIKeyMask.mask("short"), "••••")
        let secret = "sk-test-fixture-not-a-real-key-0001"
        let redacted = AIKeyMask.redact("rejected \(secret) now", secrets: [secret])
        XCTAssertFalse(redacted.contains(secret))
        XCTAssertTrue(redacted.contains("sk-…0001"))
    }

    func testAlignmentScoresToneMarksAndMissingWords() {
        let dictionary = ["กิน", "ข้าว", "น้ำ", "ก่า", "ก้า"]
        let perfect = SpeakAlign.score(target: "กินข้าว", heard: "กินข้าว", dictionary: dictionary)
        XCTAssertEqual(perfect.score, 100)
        XCTAssertEqual(perfect.pieces.map(\.status), [.match, .match])
        XCTAssertTrue(perfect.note.contains("不是声学"))

        let swapped = SpeakAlign.score(target: "กินข้าว", heard: "กินน้ำ", dictionary: dictionary)
        XCTAssertEqual(swapped.score, 50)
        XCTAssertEqual(swapped.pieces.map(\.status), [.match, .wrong])

        let tone = SpeakAlign.score(target: "ก่า", heard: "ก้า", dictionary: dictionary)
        XCTAssertEqual(tone.pieces.map(\.status), [.tone])
        XCTAssertEqual(tone.score, 65)

        let missing = SpeakAlign.score(target: "กินข้าว", heard: "กิน", dictionary: dictionary)
        XCTAssertTrue(missing.pieces.contains { $0.status == .missing && $0.text == "ข้าว" })
        XCTAssertLessThan(missing.score, 100)
    }

    func testExerciseJSONAndLocalFallback() throws {
        let raw = """
        ```json
        {"exercises":[
          {"id":"1","kind":"fill_blank","prompt":"填空","thai":"ฉัน____","chinese":"我吃","answer":"กิน","choices":[],"blank":"กิน"},
          {"id":"2","kind":"toThai","prompt":"写成泰文","thai":"","chinese":"吃","answer":"กิน","choices":[],"blank":""},
          {"id":"3","kind":"toChinese","prompt":"什么意思","thai":"กิน","chinese":"","answer":"吃","choices":[],"blank":""},
          {"id":"4","kind":"listening","prompt":"听写","thai":"กินข้าว","chinese":"吃饭","answer":"กินข้าว","choices":[],"blank":""},
          {"id":"5","kind":"dialogue","prompt":"回复","thai":"ไปไหม","chinese":"去吗","answer":"ไปครับ","choices":[],"blank":""}
        ]}
        ```
        """
        let batch = try AIExerciseService.decode(raw)
        XCTAssertTrue(AIExerciseService.issues(batch).isEmpty)
        XCTAssertEqual(batch.exercises.map(\.kind), [.fillBlank, .toThai, .toChinese, .listening, .dialogue])
        XCTAssertFalse(AIExerciseService.issues(AIExerciseBatch(exercises: [])).isEmpty)

        let catalog = try ContentLoader.load(from: contentRoot())
        var progress = LearningProgress.fresh(start: CivilDay(year: 2026, month: 10, day: 3))
        if let word = catalog.words.first {
            progress.cards[word.id] = CardState(
                easeFactor: 2.5,
                intervalDays: 1,
                repetitions: 1,
                due: progress.startDate,
                lapses: 0,
                introducedOn: progress.startDate,
                lastReviewed: progress.startDate,
                stage: .learning
            )
        }
        let local = LocalExercises.make(catalog: catalog, progress: progress, topic: "")
        XCTAssertGreaterThanOrEqual(local.exercises.count, 4)
        XCTAssertTrue(AIExerciseService.issues(local).isEmpty)
        let words = LearnedWords.list(catalog: catalog, progress: progress, topic: "", limit: 5).map(\.thai)
        let prompt = AIExerciseService.messages(words: words, topic: "食物", level: "入门").map(\.content).joined()
        XCTAssertTrue(prompt.contains("食物"))
        XCTAssertFalse(prompt.contains("sk-"))
        if let word = words.first { XCTAssertTrue(prompt.contains(word)) }

        let correction = try AIGrader.decode("""
        {"corrected":"กินข้าว","romanization":"kin khâao","explanation":"可以这么说。","score":90}
        """)
        XCTAssertEqual(correction.score, 90)
        XCTAssertThrowsError(try AIGrader.decode("{\"corrected\":\"\",\"romanization\":\"\",\"explanation\":\"\",\"score\":4}"))
    }

    func testGenerateRetriesInvalidJSON() async throws {
        let chat = ScriptedChat(replies: [
            "不是 JSON",
            """
            {"exercises":[
              {"id":"1","kind":"toThai","prompt":"写成泰文","thai":"","chinese":"吃","answer":"กิน","choices":[],"blank":""}
            ]}
            """
        ])
        let batch = try await AIExerciseService.generate(chat: chat, words: ["กิน"], topic: "食物", level: "入门")
        XCTAssertEqual(batch.exercises.count, 1)
        XCTAssertEqual(chat.calls, 2)
    }

    func testUsageCapAndCacheDigest() {
        var usage = AIUsage(dailyCap: 2)
        let day = CivilDay(year: 2026, month: 10, day: 3)
        XCTAssertTrue(usage.allows(day))
        usage.record(on: day)
        usage.record(on: day)
        XCTAssertFalse(usage.allows(day))
        XCTAssertEqual(AICacheKey.sha256("abc"), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        let wav = WAVAudio.pcm16(samples: [0, 0.5, -0.5], sampleRate: 16000)
        XCTAssertEqual(wav.prefix(4), Data("RIFF".utf8))
        var progress = LearningProgress.fresh(start: day)
        progress.recordSpeakAttempt(SpeakAttempt(id: "1", target: "กิน", transcript: "กิน", score: 100, on: day.iso))
        let encoded = try? JSONEncoder().encode(progress)
        let text = String(data: encoded ?? Data(), encoding: .utf8) ?? ""
        XCTAssertFalse(text.contains("apiKey"))
        XCTAssertTrue(text.contains("กิน"))
    }

    func testClientsAgainstMockedURLProtocol() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockAIProtocol.self]
        let session = URLSession(configuration: config)
        let transport = URLSessionAITransport(session: session)
        let secret = "sk-test-fixture-not-a-real-key-0001"
        let credential = AICredential(
            id: "openai-1",
            provider: .openai,
            label: "OpenAI",
            apiKey: secret,
            baseURL: "https://example.invalid/v1",
            models: ["gpt-4o-mini"]
        )

        MockAIProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/v1/chat/completions")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(secret)")
            let body = """
            {"choices":[{"message":{"content":"{\\"thai\\":\\"สวัสดี\\",\\"chinese\\":\\"你好\\"}"}}]}
            """
            return (200, Data(body.utf8), "application/json")
        }
        let chat = try AIClients.chat(credential, model: "gpt-4o-mini", transport: transport)
        let reply = try await chat.complete(messages: [.user("你好")], jsonObject: false)
        XCTAssertTrue(reply.contains("สวัสดี"))

        MockAIProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/v1/audio/speech")
            return (200, Data([1, 2, 3, 4]), "audio/mpeg")
        }
        let speaker = try AIClients.speech(credential, model: "tts-1", voice: "nova", transport: transport)
        let audio = try await speaker.synthesize(text: "สวัสดี", speed: 1)
        XCTAssertEqual(audio, Data([1, 2, 3, 4]))

        MockAIProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/v1/audio/transcriptions")
            XCTAssertTrue(request.value(forHTTPHeaderField: "Content-Type")?.contains("multipart/form-data") == true)
            return (200, Data("{\"text\":\"กินข้าว\"}".utf8), "application/json")
        }
        let recognizer = try AIClients.recognizer(credential, model: "whisper-1", transport: transport)
        let transcript = try await recognizer.transcribe(audioWAV: WAVAudio.pcm16(samples: [0.1], sampleRate: 16000))
        XCTAssertEqual(transcript, "กินข้าว")

        MockAIProtocol.handler = { request in
            let leaked = "nope \(secret)"
            return (401, Data(leaked.utf8), "text/plain")
        }
        let failure = await AIClients.probe(credential, model: "gpt-4o-mini", transport: transport)
        XCTAssertTrue(failure.contains("401"))
        XCTAssertFalse(failure.contains(secret))
        XCTAssertTrue(failure.contains("sk-…0001"))

        MockAIProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/v1/models")
            return (200, Data("{\"data\":[]}".utf8), "application/json")
        }
        let ok = await AIClients.probe(credential, model: nil, transport: transport)
        XCTAssertEqual(ok, "连接成功")

        let eleven = AICredential(id: "eleven-1", provider: .elevenlabs, label: "ElevenLabs", apiKey: "eleven-test-key-qrstuv")
        MockAIProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/v1/user")
            XCTAssertEqual(request.value(forHTTPHeaderField: "xi-api-key"), eleven.apiKey)
            return (200, Data("{}".utf8), "application/json")
        }
        let elevenOK = await AIClients.probe(eleven, model: nil, transport: transport)
        XCTAssertEqual(elevenOK, "连接成功")

        let azure = AICredential(id: "azure-1", provider: .azure, label: "Azure", apiKey: "azurekeytest1234567890", region: "southeastasia")
        MockAIProtocol.handler = { request in
            XCTAssertEqual(request.url?.host, "southeastasia.tts.speech.microsoft.com")
            return (200, Data("[]".utf8), "application/json")
        }
        let azureOK = await AIClients.probe(azure, model: nil, transport: transport)
        XCTAssertEqual(azureOK, "连接成功")
    }
}

private final class ScriptedChat: ChatModel {
    var replies: [String]
    var calls = 0

    init(replies: [String]) {
        self.replies = replies
    }

    func complete(messages: [AIChatMessage], jsonObject: Bool) async throws -> String {
        let reply = replies[min(calls, replies.count - 1)]
        calls += 1
        return reply
    }
}

private final class MockAIProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, Data, String))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (status, data, mime) = try handler(request)
            let response = HTTPURLResponse(
                url: request.url ?? URL(string: "https://example.invalid")!,
                statusCode: status,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": mime]
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private func contentRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Content")
}
