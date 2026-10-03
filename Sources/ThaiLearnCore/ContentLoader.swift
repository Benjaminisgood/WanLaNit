import Foundation

public struct ContentError: Error, Equatable, CustomStringConvertible {
    public var issues: [String]

    // Memberwise inits stay internal unless written out. The app target constructs this.
    public init(issues: [String]) {
        self.issues = issues
    }

    public var description: String {
        issues.joined(separator: "\n")
    }
}

public enum ContentLoader {
    /// Marker file. The app bundle is usable only when this sits next to the other course JSON.
    public static let markerFileName = "phrases.json"

    /// Directories inside `bundle` that may hold the course JSON.
    /// XcodeGen groups copy files flat into Contents/Resources. A folder reference keeps a Content subdirectory.
    /// SwiftPM also nests a `ThaiLearn_ThaiLearnCore.bundle` (or `.resources`) inside the app.
    public static func candidateDirectories(in bundle: Bundle) -> [URL] {
        var urls: [URL] = []
        func add(_ url: URL?) {
            guard let url else { return }
            let path = url.standardizedFileURL.path
            guard !urls.contains(where: { $0.standardizedFileURL.path == path }) else { return }
            urls.append(url)
        }

        func addTree(_ root: URL?) {
            guard let root else { return }
            add(root)
            add(root.appendingPathComponent("Content", isDirectory: true))
            addNestedResourceBundles(in: root, add: add)
        }

        addTree(bundle.resourceURL)
        let root = bundle.bundleURL
        addTree(root)
        addTree(root.appendingPathComponent("Contents/Resources", isDirectory: true))
        addTree(root.appendingPathComponent("Resources", isDirectory: true))
        return urls
    }

    /// Load course JSON from one bundle. Does not consult other bundles.
    public static func load(from bundle: Bundle) -> Result<Catalog, ContentError> {
        load(from: candidateDirectories(in: bundle))
    }

    /// Load course JSON shipped with the running app.
    /// Looks through `Bundle.main` first. `Bundle.module` is only consulted for SwiftPM builds,
    /// and only when the app bundle does not already contain the course, so a missing resource
    /// bundle cannot abort launch after the JSON has been copied into the app.
    public static func loadApplicationContent() -> Result<Catalog, ContentError> {
        var directories = candidateDirectories(in: .main)
        if !directories.contains(where: markerExists) {
            #if SWIFT_PACKAGE
            for directory in candidateDirectories(in: .module) {
                let path = directory.standardizedFileURL.path
                guard !directories.contains(where: { $0.standardizedFileURL.path == path }) else { continue }
                directories.append(directory)
            }
            #endif
        }
        return load(from: directories)
    }

    /// Load from the first candidate directory that contains `phrases.json`.
    /// If none do, the error lists every path that was tried.
    public static func load(from directories: [URL]) -> Result<Catalog, ContentError> {
        var tried: [String] = []
        for directory in directories {
            let marker = directory.appendingPathComponent(markerFileName)
            tried.append(marker.path)
            guard FileManager.default.fileExists(atPath: marker.path) else { continue }
            do {
                return .success(try load(from: directory))
            } catch let error as ContentError {
                return .failure(error)
            } catch {
                return .failure(ContentError(issues: [error.localizedDescription]))
            }
        }

        var issues = ["应用里没有课程文件。", "找过这些位置："]
        if tried.isEmpty {
            issues.append("（没有可搜索的路径）")
        } else {
            issues.append(contentsOf: tried)
        }
        return .failure(ContentError(issues: issues))
    }

    private static func markerExists(_ directory: URL) -> Bool {
        FileManager.default.fileExists(
            atPath: directory.appendingPathComponent(markerFileName).path
        )
    }

    /// SwiftPM resource bundles copied into an app: `Name.bundle` on Apple, `Name.resources` on Linux.
    private static func addNestedResourceBundles(in directory: URL, add: (URL?) -> Void) {
        guard let children = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }
        for child in children {
            let name = child.lastPathComponent
            guard name.hasSuffix(".bundle") || name.hasSuffix(".resources") else { continue }
            add(child)
            add(child.appendingPathComponent("Content", isDirectory: true))
            add(child.appendingPathComponent("Contents/Resources", isDirectory: true))
            add(child.appendingPathComponent("Contents/Resources/Content", isDirectory: true))
        }
    }

    public static func load(from directory: URL) throws -> Catalog {
        var issues: [String] = []
        let decks: [Deck] = decode("decks.json", from: directory, issues: &issues) ?? []
        let phrases: [Phrase] = decode("phrases.json", from: directory, issues: &issues) ?? []
        let consonants: [Consonant] = decode("consonants.json", from: directory, issues: &issues) ?? []
        let vowels: [Vowel] = decode("vowels.json", from: directory, issues: &issues) ?? []
        let tones: [ToneLesson] = decode("tones.json", from: directory, issues: &issues) ?? []
        let minimalSets: [MinimalSet] = decode("minimal_sets.json", from: directory, issues: &issues) ?? []
        let sounds: [SoundLesson] = decode("sounds.json", from: directory, issues: &issues) ?? []
        let culture: [CultureNote] = decode("culture.json", from: directory, issues: &issues) ?? []
        let words: [VocabWord] = decode("words.json", from: directory, issues: &issues) ?? []
        let starters: [StarterText] = decode("starters.json", from: directory, issues: &issues) ?? []
        let passages: [ReadingPassage] = decode("passages.json", from: directory, issues: &issues) ?? []

        if !issues.isEmpty {
            throw ContentError(issues: issues)
        }

        let catalog = Catalog(
            decks: decks,
            phrases: phrases,
            consonants: consonants,
            vowels: vowels,
            tones: tones,
            minimalSets: minimalSets,
            sounds: sounds,
            culture: culture,
            words: words,
            starters: starters,
            passages: passages
        )
        let validation = validate(catalog)
        if !validation.isEmpty {
            throw ContentError(issues: validation)
        }
        return catalog
    }

    public static func validate(_ catalog: Catalog) -> [String] {
        var issues: [String] = []
        validateIdentity(catalog, issues: &issues)
        validatePhrases(catalog, issues: &issues)
        validateConsonants(catalog, issues: &issues)
        validateVowels(catalog, issues: &issues)
        validateTones(catalog, issues: &issues)
        validateMinimalSets(catalog, issues: &issues)
        validateSounds(catalog, issues: &issues)
        validateCulture(catalog, issues: &issues)
        validateWords(catalog, issues: &issues)
        validateStarters(catalog, issues: &issues)
        validatePassages(catalog, issues: &issues)
        return issues
    }

    private static func decode<T: Decodable>(
        _ name: String,
        from directory: URL,
        issues: inout [String]
    ) -> T? {
        let url = directory.appendingPathComponent(name)
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            issues.append("找不到内容文件 \(name)")
            return nil
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            issues.append("\(name) 读不出来：\(error)")
            return nil
        }
    }

    private static func validateIdentity(_ catalog: Catalog, issues: inout [String]) {
        var seen: [String: String] = [:]
        func claim(_ id: String, _ kind: String) {
            if id.isEmpty {
                issues.append("\(kind) 有空的 id")
                return
            }
            if let previous = seen[id] {
                issues.append("id「\(id)」重复了（\(previous) 和 \(kind)）")
            } else {
                seen[id] = kind
            }
        }
        if catalog.decks.isEmpty { issues.append("至少要有一个词组") }
        for deck in catalog.decks { claim(deck.id, "词组") }
        for phrase in catalog.phrases { claim(phrase.id, "句子") }
        for consonant in catalog.consonants { claim(consonant.id, "辅音") }
        for vowel in catalog.vowels { claim(vowel.id, "元音") }
        for word in catalog.words { claim(word.id, "词") }
        let deckIDs = Set(catalog.decks.map(\.id))
        for phrase in catalog.phrases where !deckIDs.contains(phrase.deck) {
            issues.append("句子 \(phrase.id) 的词组 \(phrase.deck) 不存在")
        }
    }

    private static func validatePhrases(_ catalog: Catalog, issues: inout [String]) {
        if catalog.phrases.count < 150 {
            issues.append("句子只有 \(catalog.phrases.count) 条，至少要 150 条")
        }
        let required = [
            "สวัสดีครับ",
            "ขอบคุณครับ",
            "ไม่เป็นไร",
            "ขอโทษครับ",
            "ยินดีที่ได้รู้จักครับ",
            "คุณมาจากไหนครับ",
            "กินข้าวหรือยังครับ",
            "คุณน่ารักมาก",
            "ผมกำลังเรียนภาษาไทยครับ"
        ]
        for text in required where !catalog.phrases.contains(where: { $0.thai == text }) {
            issues.append("缺少句子：\(text)")
        }
        if !catalog.phrases.contains(where: { $0.thai.contains("ผมชื่อ") && $0.thai.contains("ครับ") }) {
            issues.append("缺少自我介绍：ผมชื่อ…ครับ")
        }
        for phrase in catalog.phrases {
            if !containsThai(phrase.thai) {
                issues.append("\(phrase.id) 的泰文是空的")
            }
            if phrase.meaning.trimmingCharacters(in: .whitespaces).isEmpty {
                issues.append("\(phrase.id) 没有中文意思")
            }
            if phrase.syllables.isEmpty {
                issues.append("\(phrase.id) 没有音节切分")
                continue
            }
            checkSyllableGroup(
                phrase.syllables,
                owner: phrase.id,
                joined: phrase.romanization,
                spelling: phrase.thai,
                issues: &issues
            )
        }
    }

    private static func validateConsonants(_ catalog: Catalog, issues: inout [String]) {
        let expected = ThaiAlphabet.entries
        if catalog.consonants.count != expected.count {
            issues.append("辅音应有 \(expected.count) 个，现在是 \(catalog.consonants.count) 个")
        }
        let sorted = catalog.consonants.sorted { $0.order < $1.order }
        if sorted.map(\.symbol) != expected.map(\.symbol) {
            issues.append("辅音顺序或字母和四十四字母表不一致")
        }
        for (consonant, entry) in zip(sorted, expected) {
            if consonant.consonantClass != entry.consonantClass {
                issues.append("\(consonant.symbol) 的类应是 \(entry.consonantClass.chinese)")
            }
            if consonant.obsolete != entry.obsolete {
                issues.append("\(consonant.symbol) 的废字母标记不对")
            }
            if consonant.initial.isEmpty {
                issues.append("\(consonant.symbol) 没有声母罗马音")
            }
            if consonant.nameThai.isEmpty || consonant.meaning.isEmpty {
                issues.append("\(consonant.symbol) 的名字不完整")
            }
            checkSyllableGroup(
                consonant.syllables,
                owner: consonant.symbol,
                joined: consonant.nameRoman,
                spelling: consonant.nameThai,
                issues: &issues
            )
        }
    }

    private static func validateVowels(_ catalog: Catalog, issues: inout [String]) {
        if catalog.vowels.count < 24 {
            issues.append("元音只有 \(catalog.vowels.count) 个，主要元音至少要 24 个")
        }
        var seen: Set<String> = []
        for vowel in catalog.vowels {
            if !seen.insert(vowel.id).inserted {
                issues.append("元音 id 重复：\(vowel.id)")
            }
            if vowel.symbols.isEmpty || vowel.roman.isEmpty || vowel.soundHint.isEmpty {
                issues.append("元音 \(vowel.id) 说明不完整")
            }
            checkSyllableGroup(
                vowel.syllables,
                owner: vowel.id,
                joined: vowel.exampleRoman,
                spelling: vowel.exampleThai,
                issues: &issues
            )
        }
    }

    private static func validateTones(_ catalog: Catalog, issues: inout [String]) {
        let tones = catalog.tones.map(\.tone)
        if tones.sorted(by: { $0.rawValue < $1.rawValue }) != Tone.allCases.sorted(by: { $0.rawValue < $1.rawValue }) {
            issues.append("声调课必须正好覆盖五个声调")
        }
        for lesson in catalog.tones {
            if RomanTone.tone(in: lesson.exampleRoman) != lesson.tone {
                issues.append("声调例子 \(lesson.exampleThai) 的罗马音调和 \(lesson.tone.chinese) 不一致")
            }
            if lesson.mandarin.isEmpty || lesson.pitch.isEmpty {
                issues.append("\(lesson.tone.chinese) 缺少和普通话的对照")
            }
        }
    }

    private static func validateMinimalSets(_ catalog: Catalog, issues: inout [String]) {
        if catalog.minimalSets.isEmpty {
            issues.append("缺少声调最小对立组")
        }
        let classic: [(String, Tone)] = [
            ("คา", .mid),
            ("ข่า", .low),
            ("ค่า", .falling),
            ("ค้า", .high),
            ("ขา", .rising)
        ]
        let items = catalog.minimalSets.flatMap(\.items)
        for (thai, tone) in classic {
            guard let item = items.first(where: { $0.thai == thai }) else {
                issues.append("最小对立组缺少 \(thai)")
                continue
            }
            if item.tone != tone {
                issues.append("\(thai) 应是 \(tone.chinese)")
            }
        }
        for set in catalog.minimalSets {
            for item in set.items {
                if !sameRoman(item.roman, item.syllable.roman) {
                    issues.append("\(set.id) 里 \(item.thai) 的罗马音和音节不一致")
                }
                if RomanTone.tone(in: item.roman) != item.tone {
                    issues.append("\(item.thai) 标成 \(item.tone.chinese)，罗马音却不是这个调")
                }
                checkSyllable(item.syllable, owner: item.thai, issues: &issues)
                if item.syllable.exception == nil, item.syllable.expectedTone != item.tone {
                    issues.append("\(item.thai) 的规则声调不是 \(item.tone.chinese)")
                }
            }
        }
    }

    private static func validateSounds(_ catalog: Catalog, issues: inout [String]) {
        let needed = ["voiced-stops", "initial-ng", "unreleased-finals", "aspiration"]
        let ids = Set(catalog.sounds.map(\.id))
        for id in needed where !ids.contains(id) {
            issues.append("缺少发音专题 \(id)")
        }
        for lesson in catalog.sounds {
            if lesson.problem.isEmpty || lesson.howTo.isEmpty || lesson.pairs.isEmpty {
                issues.append("发音专题 \(lesson.id) 内容不完整")
            }
            for pair in lesson.pairs where !containsThai(pair.thai) || pair.roman.isEmpty || pair.meaning.isEmpty {
                issues.append("发音例子不完整：\(lesson.id)")
            }
        }
    }

    private static func validateWords(_ catalog: Catalog, issues: inout [String]) {
        if catalog.words.count < 1000 {
            issues.append("词汇只有 \(catalog.words.count) 个，至少要 1000 个")
        }
        var seenThai: Set<String> = []
        for word in catalog.words {
            if word.thai.isEmpty || !containsThai(word.thai) {
                issues.append("\(word.id) 没有泰文")
            }
            if !seenThai.insert(word.thai).inserted {
                issues.append("泰文重复：\(word.thai)")
            }
            if word.romanization.trimmingCharacters(in: .whitespaces).isEmpty {
                issues.append("\(word.id) 没有罗马音")
            }
            if word.meaning.trimmingCharacters(in: .whitespaces).isEmpty {
                issues.append("\(word.id) 没有中文")
            }
            if !(1...4).contains(word.band) {
                issues.append("\(word.id) 的词频档必须是 1 到 4")
            }
            if word.topic.trimmingCharacters(in: .whitespaces).isEmpty {
                issues.append("\(word.id) 没有话题")
            }
        }
    }

    private static func validateStarters(_ catalog: Catalog, issues: inout [String]) {
        if catalog.starters.count < 3 {
            issues.append("入门短文至少要 3 篇")
        }
        var seen: Set<String> = []
        for text in catalog.starters {
            if !seen.insert(text.id).inserted {
                issues.append("短文 id 重复：\(text.id)")
            }
            if text.title.isEmpty || text.body.count < 20 {
                issues.append("短文 \(text.id) 太短")
            }
            if !(1...3).contains(text.level) {
                issues.append("短文 \(text.id) 的难度必须是 1 到 3")
            }
        }
    }

    private static func validatePassages(_ catalog: Catalog, issues: inout [String]) {
        if catalog.passages.count < 30 {
            issues.append("精读只有 \(catalog.passages.count) 篇，至少要 30 篇")
        }
        let topics = Set(["日常生活", "食物", "旅行", "交朋友", "泰国文化"])
        var perLevel: [Int: Int] = [:]
        for passage in catalog.passages {
            perLevel[passage.level, default: 0] += 1
            if !(1...4).contains(passage.level) {
                issues.append("短文 \(passage.id) 的难度必须是 1 到 4")
            }
            if !topics.contains(passage.topic) {
                issues.append("短文 \(passage.id) 的话题不在范围内")
            }
            if passage.title.isEmpty || passage.chinese.isEmpty {
                issues.append("短文 \(passage.id) 缺少标题或译文")
            }
            if !containsThai(passage.thai) {
                issues.append("短文 \(passage.id) 没有泰文")
            }
            let sentences = passage.sentences
            switch passage.level {
            case 1 where !(2...3).contains(sentences.count):
                issues.append("短文 \(passage.id) 是入门篇，要有 2 到 3 句，现在 \(sentences.count) 句")
            case 4 where sentences.count < 5 || passage.thai.unicodeScalars.count < 80:
                issues.append("短文 \(passage.id) 作为第四级太短")
            default:
                break
            }
            if passage.glosses.isEmpty {
                issues.append("短文 \(passage.id) 没有词注")
            }
            for gloss in passage.glosses where !passage.thai.contains(gloss.thai) || gloss.romanization.isEmpty || gloss.meaning.isEmpty {
                issues.append("短文 \(passage.id) 的词注「\(gloss.thai)」对不上")
            }
            if !(3...4).contains(passage.questions.count) {
                issues.append("短文 \(passage.id) 要有 3 到 4 道理解题")
            }
            for question in passage.questions {
                if question.choices.count < 3 || !question.choices.indices.contains(question.answer) {
                    issues.append("短文 \(passage.id) 有一道题的选项不对")
                }
            }
        }
        for level in 1...4 where (perLevel[level] ?? 0) < 6 {
            issues.append("第 \(level) 级短文不够")
        }
    }

    private static func validateCulture(_ catalog: Catalog, issues: inout [String]) {
        if catalog.culture.count < 6 {
            issues.append("文化笔记至少 6 则")
        }
        for note in catalog.culture where note.title.isEmpty || note.body.count < 20 {
            issues.append("文化笔记 \(note.id) 太短")
        }
    }

    private static func checkSyllableGroup(
        _ syllables: [Syllable],
        owner: String,
        joined: String,
        spelling: String,
        issues: inout [String]
    ) {
        if syllables.isEmpty {
            issues.append("\(owner) 没有音节")
            return
        }
        let words = Set(syllables.map(\.word))
        let maxWord = syllables.map(\.word).max() ?? 0
        if words != Set(0...maxWord) || syllables.first?.word != 0 {
            issues.append("\(owner) 的音节分组不连续")
        }
        if !sameRoman(joined, RomanizationJoiner.join(syllables)) {
            issues.append("\(owner) 的罗马音和音节拼起来不一致：\(joined)")
        }
        for syllable in syllables {
            checkSyllable(syllable, owner: owner, issues: &issues)
        }
        let spellingMarks = ThaiScriptMarks.toneMarks(in: spelling)
        let syllableMarks = syllables.flatMap { ThaiScriptMarks.toneMarks(in: $0.thai) }
        if spelling.contains("ๆ") {
            for mark in spellingMarks where !syllableMarks.contains(mark) {
                issues.append("\(owner) 的 ๆ 句子丢了声调符号")
            }
        } else if spellingMarks != syllableMarks {
            issues.append("\(owner) 拼写里的声调符号和音节切分对不上")
        }
    }

    private static func checkSyllable(_ syllable: Syllable, owner: String, issues: inout [String]) {
        let found = ThaiScriptMarks.toneMarks(in: syllable.thai)
        switch syllable.toneMark {
        case .none:
            if !found.isEmpty {
                issues.append("\(owner) 的音节 \(syllable.thai) 写了声调符号，却标成无符号")
            }
        default:
            if found != [syllable.toneMark] {
                issues.append("\(owner) 的音节 \(syllable.thai) 的声调符号不是 \(syllable.toneMark.chinese)")
            }
        }
        if syllable.roman.isEmpty {
            issues.append("\(owner) 有音节没有罗马音")
            return
        }
        let marked = RomanTone.tone(in: syllable.roman)
        if let exception = syllable.exception {
            if exception.trimmingCharacters(in: .whitespaces).isEmpty {
                issues.append("\(owner) 的例外说明是空的")
            }
        } else if marked != syllable.expectedTone {
            issues.append("\(owner) 的 \(syllable.thai)（\(syllable.roman)）按规则应是 \(syllable.expectedTone.chinese)，罗马音却是 \(marked.chinese)")
        }
    }

    private static func containsThai(_ text: String) -> Bool {
        text.unicodeScalars.contains { (0x0E00...0x0E7F).contains($0.value) }
    }

    private static func sameRoman(_ lhs: String, _ rhs: String) -> Bool {
        lhs.decomposedStringWithCanonicalMapping == rhs.decomposedStringWithCanonicalMapping
    }
}
