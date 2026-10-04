import XCTest
import ThaiLearnCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class TutorTests: XCTestCase {
    func testSnapshotMemoryAndOfflineLesson() throws {
        let catalog = try ContentLoader.load(from: contentRoot())
        let today = CivilDay(year: 2026, month: 10, day: 4)
        var progress = LearningProgress.fresh(start: CivilDay(year: 2026, month: 10, day: 2))
        let phrase = try XCTUnwrap(catalog.phrases.first)
        var card = CardState.fresh(on: today)
        card.lapses = 2
        card.stage = .review
        progress.cards[phrase.id] = card
        progress.typing.misses["ก"] = 3
        progress.streak = 2
        progress.tutor.addNote("他把句尾的 ครับ 漏了", on: today.iso)
        let snapshot = LearnerModel.snapshot(catalog: catalog, progress: progress, today: today)
        XCTAssertEqual(snapshot.lapses.first?.id, phrase.id)
        XCTAssertEqual(snapshot.lapses.first?.lapses, 2)
        XCTAssertEqual(snapshot.typingWeakKeys.first, "ก")
        XCTAssertEqual(snapshot.streak, 2)
        XCTAssertTrue(snapshot.speech.contains("ครับ"))
        XCTAssertTrue(snapshot.statedGoals.contains("泰国"))
        XCTAssertFalse(snapshot.grounded.isEmpty)
        XCTAssertEqual(snapshot.memory, ["他把句尾的 ครับ 漏了"])

        let lesson = OfflineTutor.lesson(catalog: catalog, progress: progress, today: today)
        XCTAssertTrue(lesson.assistantText.contains("ครับ"))
        XCTAssertTrue(lesson.steps.contains { $0.card != nil || $0.exercise?.kind == "quiz" || $0.exercise?.kind == "review" })
        XCTAssertFalse(lesson.homework.isEmpty)
        let week = OfflineTutor.weekPlan(catalog: catalog, progress: progress, today: today)
        XCTAssertFalse(week.milestones.isEmpty)
        let reply = OfflineTutor.localReply(userText: phrase.thai, context: "句子", catalog: catalog, progress: progress, today: today)
        XCTAssertTrue(reply.contains(phrase.romanization))

        let data = try JSONEncoder().encode(progress)
        let again = try JSONDecoder().decode(LearningProgress.self, from: data)
        XCTAssertEqual(again.tutor.notes.first?.text, "他把句尾的 ครับ 漏了")
    }

    func testToolSchemaDispatchAndAgent() async throws {
        let catalog = try ContentLoader.load(from: contentRoot())
        let today = CivilDay(year: 2026, month: 10, day: 4)
        var progress = LearningProgress.fresh(start: today)
        let encoded = try JSONEncoder().encode(TutorTools.specs)
        let decoded = try JSONDecoder().decode([TutorToolSpec].self, from: encoded)
        XCTAssertEqual(decoded.map(\.name), TutorTools.names)
        XCTAssertTrue(decoded.contains { $0.name == "get_learner_snapshot" && $0.parameters.contains("object") })

        let phrase = try XCTUnwrap(catalog.phrases.first)
        let added = TutorDispatch.apply(
            LLMToolCall(id: "add", name: "add_cards", arguments: "{\"items\":[\"\(phrase.id)\"]}"),
            catalog: catalog,
            progress: &progress,
            today: today
        )
        XCTAssertTrue(added.resultJSON.contains(phrase.id))
        XCTAssertNotNil(progress.cards[phrase.id])
        _ = TutorDispatch.apply(
            LLMToolCall(id: "mem", name: "update_memory", arguments: "{\"note\":\"短句比长解释有效\"}"),
            catalog: catalog,
            progress: &progress,
            today: today
        )
        XCTAssertEqual(progress.tutor.notes.first?.text, "短句比长解释有效")
        let rejected = TutorDispatch.apply(
            LLMToolCall(id: "bad", name: "teach_item", arguments: "{\"thai\":\"ไม่มีทางเป็นคำในบทเรียนนี้ครับ\",\"explanation\":\"编的\"}"),
            catalog: catalog,
            progress: &progress,
            today: today
        )
        XCTAssertNil(rejected.card)
        XCTAssertTrue(rejected.resultJSON.contains("不在课程词表"))
        XCTAssertNil(TutorGrounding.card(id: "", thai: "ไม่มีทางเป็นคำในบทเรียนนี้ครับ", explanation: "", catalog: catalog))

        let questions = TutorQuiz.make(items: [phrase.id], type: "toChinese", catalog: catalog)
        let question = try XCTUnwrap(questions.first)
        XCTAssertEqual(question.choices[question.answer], phrase.meaning)

        final class Script: @unchecked Sendable {
            var turns: [LLMTurn]
            var calls = 0
            init(_ turns: [LLMTurn]) { self.turns = turns }
        }
        let script = Script([
            LLMTurn(
                text: "先记下这个错。",
                calls: [LLMToolCall(id: "c1", name: "log_mistake", arguments: "{\"thai\":\"\(phrase.thai)\",\"expected\":\"\(phrase.thai)\",\"heard\":\"x\",\"note\":\"漏了ครับ\",\"source\":\"tutor\"}")],
                tokens: 30
            ),
            LLMTurn(text: "下一句仍用 ครับ。", calls: [], tokens: 12)
        ])
        let taught = await TutorAgent.respond(
            fetch: { _ in
                let turn = script.turns[min(script.calls, script.turns.count - 1)]
                script.calls += 1
                return turn
            },
            userText: "开始今天的课",
            catalog: catalog,
            progress: progress,
            today: today,
            context: "AI 老师"
        )
        XCTAssertEqual(script.calls, 2)
        XCTAssertFalse(taught.usedFallback)
        XCTAssertEqual(taught.assistantText, "下一句仍用 ครับ。")
        XCTAssertTrue(taught.progress.tutor.mistakes.contains { $0.note == "漏了ครับ" })
        XCTAssertEqual(taught.progress.tutor.requests(on: today), 2)

        let review = await TutorAgent.respond(
            fetch: { _ in
                LLMTurn(text: "先复习。", calls: [LLMToolCall(id: "r1", name: "start_review", arguments: "{\"deck\":\"due\",\"count\":4}")], tokens: 8)
            },
            userText: "继续",
            catalog: catalog,
            progress: progress,
            today: today,
            context: "复习"
        )
        XCTAssertEqual(review.exercise?.kind, "review")
        XCTAssertTrue(review.queue.isEmpty)

        progress.tutor.requestCap = 0
        var fetched = false
        let offline = await TutorAgent.respond(
            fetch: { _ in
                fetched = true
                return LLMTurn(text: "不该走到", calls: [], tokens: 1)
            },
            userText: "开始今天的课",
            catalog: catalog,
            progress: progress,
            today: today,
            context: "今天"
        )
        XCTAssertFalse(fetched)
        XCTAssertTrue(offline.usedFallback)
        XCTAssertTrue(offline.assistantText.contains("ครับ"))
        XCTAssertNotNil(offline.exercise)
    }

    func testCompactionSSEAndToolHTTP() async throws {
        let turns = (0..<20).map { index in
            TutorChatTurn(id: "\(index)", role: index.isMultiple(of: 2) ? "user" : "assistant", text: "句子\(index) 还有一些多余的话", on: "2026-10-04")
        }
        let folded = TutorCompaction.compact(summary: "旧摘要", turns: turns)
        XCTAssertEqual(folded.turns.count, 8)
        XCTAssertTrue(folded.summary.contains("句子0"))
        XCTAssertLessThanOrEqual(folded.summary.count, 800)

        var decoder = TutorSSEDecoder()
        let fixture = """
        data: {"choices":[{"delta":{"content":"你"}}]}

        data: {"choices":[{"delta":{"content":"好"}}]}

        data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_1","function":{"name":"quiz","arguments":"{\\"items\\":"}}]}}]}

        data: {"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"[]}"}}]}}],"usage":{"total_tokens":12}}

        data: [DONE]
        """
        for line in fixture.split(separator: "\n") {
            _ = decoder.consume(String(line))
        }
        let streamed = decoder.turn()
        XCTAssertEqual(streamed.text, "你好")
        XCTAssertEqual(streamed.calls.first?.name, "quiz")
        XCTAssertEqual(streamed.calls.first?.arguments, "{\"items\":[]}")
        XCTAssertEqual(streamed.tokens, 12)
        XCTAssertEqual(TutorTextStream.chunks("一二三四五", size: 2), ["一二", "三四", "五"])

        let body = """
        {"choices":[{"message":{"content":"好","tool_calls":[{"id":"call_9","type":"function","function":{"name":"get_learner_snapshot","arguments":"{}"}}]}}],"usage":{"total_tokens":15}}
        """
        let transport = CaptureTransport(response: Data(body.utf8))
        let client = OpenAICompatibleClient(
            baseURL: URL(string: "https://example.invalid/v1")!,
            apiKey: "sk-test",
            transport: transport,
            chatModel: "qwen-max"
        )
        let turn = try await client.completeTurn(messages: [.user("开始今天的课")], tools: TutorTools.specs)
        XCTAssertEqual(turn.text, "好")
        XCTAssertEqual(turn.calls.first?.name, "get_learner_snapshot")
        XCTAssertEqual(turn.tokens, 15)
        let sent = String(data: transport.body, encoding: .utf8) ?? ""
        XCTAssertTrue(sent.contains("get_learner_snapshot"))
        XCTAssertTrue(sent.contains("qwen-max"))
        XCTAssertTrue(sent.contains("\"tools\""))

        var pieces: [TutorStreamPiece] = []
        for try await piece in client.streamTurn(messages: [.user("开始")], tools: TutorTools.specs) {
            pieces.append(piece)
        }
        XCTAssertTrue(pieces.contains { if case .text = $0 { return true } else { return false } })
        guard case .done(let done) = pieces.last else {
            return XCTFail("缺少结束块")
        }
        XCTAssertEqual(done.calls.first?.name, "get_learner_snapshot")
    }
}

private final class CaptureTransport: AITransport, @unchecked Sendable {
    var body = Data()
    var response: Data

    init(response: Data) {
        self.response = response
    }

    func send(_ request: URLRequest) async throws -> AIHTTPResponse {
        body = request.httpBody ?? Data()
        return AIHTTPResponse(status: 200, data: response)
    }
}

private func contentRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Content")
}
