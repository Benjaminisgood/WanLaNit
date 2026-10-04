import XCTest
import ThaiLearnCore

final class ScenarioTests: XCTestCase {
    func testScenariosAndCultureArticles() throws {
        let catalog = try ContentLoader.load(from: contentRoot())
        XCTAssertGreaterThanOrEqual(catalog.scenarios.count, 6)
        let titles = Set(catalog.scenarios.map(\.title))
        XCTAssertTrue(titles.isSuperset(of: ["认识新朋友", "约会和聊天", "点餐", "出租车和 Grab", "问路", "购物和还价"]))
        for scenario in catalog.scenarios {
            XCTAssertTrue((10...15).contains(scenario.phrases.count))
            XCTAssertTrue((1...2).contains(scenario.dialogues.count))
            XCTAssertGreaterThanOrEqual(scenario.questions.count, 3)
            XCTAssertGreaterThanOrEqual(scenario.goals.count, 3)
            XCTAssertFalse(scenario.persona.brief.isEmpty)
            XCTAssertTrue(scenario.phrases.allSatisfy { $0.thai.contains("ครับ") })
        }
        let rich = catalog.culture.filter { $0.phrases.count >= 3 && $0.questions.count == 3 }
        XCTAssertGreaterThanOrEqual(rich.count, 15)
        XCTAssertTrue(ContentLoader.toneMarkBeforeVowel("ข้าว"))
        XCTAssertFalse(ContentLoader.toneMarkBeforeVowel("ข้า" + "้"))
    }

    func testFuzzyReplyAndCoachFallback() async {
        XCTAssertTrue(ScenarioMatch.matches("  ผมชื่อเบนครับ  ", candidates: ["ผมชื่อเบน"]))
        XCTAssertTrue(ScenarioMatch.matches("ขอไลน์ได้ไหม", candidates: ["ขอไลน์ได้ไหมครับ"]))
        XCTAssertFalse(ScenarioMatch.matches("เผ็ด", candidates: ["เลี้ยวซ้ายครับ"]))
        let scenario = Scenario(
            id: "sc-test",
            title: "测试",
            setting: "测试",
            order: 1,
            goals: [ScenarioGoal(id: "greet", chinese: "打招呼")],
            phrases: [ScenarioPhrase(id: "p", thai: "สวัสดีครับ", female: "สวัสดีค่ะ", romanization: "sà-wàt-dii khráp", meaning: "你好")],
            dialogues: [],
            questions: [],
            script: [ScenarioNode(
                id: "start",
                speaker: "มิ้นท์",
                thai: "สวัสดีค่ะ",
                romanization: "sà-wàt-dii khâ",
                meaning: "你好",
                choices: [],
                typed: [],
                typedNext: "",
                typedGoals: [],
                end: true
            )],
            persona: ScenarioPersona(name: "มิ้นท์", role: "朋友", brief: "短句。", turnLimit: 2)
        )
        let raw = """
        {"thai":"ยินดีค่ะ","chinese":"很高兴认识你","correction":null,"goals":[{"id":"greet","done":true}],"finished":true,"feedback":"说到名字了。","review":["สวัสดีครับ"]}
        """
        let decoded = try? AIJSON.decode(raw, as: ScenarioCoachReply.self)
        XCTAssertEqual(decoded?.thai, "ยินดีค่ะ")
        XCTAssertTrue(ScenarioCoach.issues(decoded!, scenario: scenario).isEmpty)
        XCTAssertEqual(ScenarioCoach.score(scenario: scenario, marks: decoded!.goals), 100)
        let chat = ScriptedScenarioChat(replies: ["不是 JSON", raw])
        let outcome = await ScenarioCoach.reply(chat: chat, scenario: scenario, history: [
            ScenarioTurn(id: "1", role: "user", thai: "ผมชื่อเบนครับ", chinese: "")
        ])
        XCTAssertFalse(outcome.usedFallback)
        XCTAssertEqual(outcome.reply.feedback, "说到名字了。")
        let broken = await ScenarioCoach.reply(chat: ScriptedScenarioChat(replies: ["不行", "还是不行"]), scenario: scenario, history: [])
        XCTAssertTrue(broken.usedFallback)
        XCTAssertFalse(broken.reply.thai.isEmpty)
    }

    func testOldProgressKeepsScenarioFieldsEmpty() throws {
        let json = """
        {"cards":{},"dayLogs":[],"schema":1,"startDate":"2026-10-02","streak":1}
        """
        let progress = try JSONDecoder().decode(LearningProgress.self, from: Data(json.utf8))
        XCTAssertTrue(progress.scenarioLog.isEmpty)
        XCTAssertTrue(progress.cultureLog.isEmpty)
    }
}

private final class ScriptedScenarioChat: ChatModel {
    var replies: [String]
    var index = 0

    init(replies: [String]) {
        self.replies = replies
    }

    func complete(messages: [AIChatMessage], jsonObject: Bool) async throws -> String {
        let reply = replies[min(index, replies.count - 1)]
        index += 1
        return reply
    }
}

private func contentRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Content")
}
