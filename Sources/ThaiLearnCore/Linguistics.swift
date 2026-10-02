import Foundation

// 声调规则只看四件事：控制声母的类、有没有声调符号、音节是活是死、
// 以及（只在“低辅音 + 没有符号 + 死音节”时）元音长短。
// 有声调符号以后，不再套用无符号那一列。

public enum ConsonantClass: String, Codable, CaseIterable, Sendable {
    case mid
    case high
    case low

    public var chinese: String {
        switch self {
        case .mid: return "中辅音"
        case .high: return "高辅音"
        case .low: return "低辅音"
        }
    }
}

public enum ToneMark: String, Codable, CaseIterable, Sendable {
    case none
    case maiEk
    case maiTho
    case maiTri
    case maiChattawa

    public var chinese: String {
        switch self {
        case .none: return "无符号"
        case .maiEk: return "่ ไม้เอก"
        case .maiTho: return "้ ไม้โท"
        case .maiTri: return "๊ ไม้ตรี"
        case .maiChattawa: return "๋ ไม้จัตวา"
        }
    }

    public var character: String? {
        switch self {
        case .none: return nil
        case .maiEk: return "\u{0E48}"
        case .maiTho: return "\u{0E49}"
        case .maiTri: return "\u{0E4A}"
        case .maiChattawa: return "\u{0E4B}"
        }
    }
}

public enum SyllableEnding: String, Codable, CaseIterable, Sendable {
    /// 长开元音，或韵尾是 ม น ง ย ว（以及读成 n 的 ร ล）。
    case live
    /// 短开元音（带喉塞），或韵尾是不除阻的 p t k。
    case dead

    public var chinese: String {
        switch self {
        case .live: return "活音节"
        case .dead: return "死音节"
        }
    }
}

public enum SyllableLength: String, Codable, CaseIterable, Sendable {
    case short
    case long

    public var chinese: String {
        switch self {
        case .short: return "短"
        case .long: return "长"
        }
    }
}

public enum Tone: String, Codable, CaseIterable, Sendable {
    case mid
    case low
    case falling
    case high
    case rising

    public var chinese: String {
        switch self {
        case .mid: return "中调"
        case .low: return "低调"
        case .falling: return "降调"
        case .high: return "高调"
        case .rising: return "升调"
        }
    }

    /// Paiboon 声调符号。中调不标。
    public var markSample: String {
        switch self {
        case .mid: return "a"
        case .low: return "à"
        case .falling: return "â"
        case .high: return "á"
        case .rising: return "ǎ"
        }
    }

    public var mandarinHint: String {
        switch self {
        case .mid:
            return "接近普通话第一声，但更低、更平。不要往上扬，把阴平放在音域的中下部。"
        case .low:
            return "普通话没有单独的低调。从中偏低的地方轻轻落下，然后停住。不要从很高的地方掉下来，那是降调。"
        case .falling:
            return "很像普通话第四声：从高处明显掉下来。"
        case .high:
            return "高度接近第二声，但起点就已经很高，整体比第二声更高，不必大起大落。"
        case .rising:
            return "很像普通话第三声的拐弯：先低，再往上扬。"
        }
    }
}

public struct ToneRuling: Equatable, Sendable {
    public var tone: Tone
    /// 标准拼写里常见的组合。ไม้ตรี / ไม้จัตวา 通常只写在中辅音上。
    public var regular: Bool
    public var headline: String
    public var detail: String
}

public enum ToneEngine {
    public static func ruling(
        consonantClass: ConsonantClass,
        toneMark: ToneMark,
        ending: SyllableEnding,
        length: SyllableLength
    ) -> ToneRuling {
        let tone = tone(
            consonantClass: consonantClass,
            toneMark: toneMark,
            ending: ending,
            length: length
        )
        let regular = isRegular(
            consonantClass: consonantClass,
            toneMark: toneMark
        )
        return ToneRuling(
            tone: tone,
            regular: regular,
            headline: headline(tone: tone, regular: regular),
            detail: detail(
                consonantClass: consonantClass,
                toneMark: toneMark,
                ending: ending,
                length: length,
                tone: tone,
                regular: regular
            )
        )
    }

    public static func tone(
        consonantClass: ConsonantClass,
        toneMark: ToneMark,
        ending: SyllableEnding,
        length: SyllableLength
    ) -> Tone {
        switch toneMark {
        case .maiEk:
            switch consonantClass {
            case .mid, .high: return .low
            case .low: return .falling
            }
        case .maiTho:
            switch consonantClass {
            case .mid, .high: return .falling
            case .low: return .high
            }
        case .maiTri:
            return .high
        case .maiChattawa:
            return .rising
        case .none:
            switch (consonantClass, ending, length) {
            case (.mid, .live, _):
                return .mid
            case (.mid, .dead, _):
                return .low
            case (.high, .live, _):
                return .rising
            case (.high, .dead, _):
                return .low
            case (.low, .live, _):
                return .mid
            case (.low, .dead, .short):
                return .high
            case (.low, .dead, .long):
                return .falling
            }
        }
    }

    public static func isRegular(consonantClass: ConsonantClass, toneMark: ToneMark) -> Bool {
        switch toneMark {
        case .maiTri, .maiChattawa:
            return consonantClass == .mid
        case .none, .maiEk, .maiTho:
            return true
        }
    }

    private static func headline(tone: Tone, regular: Bool) -> String {
        regular ? tone.chinese : "\(tone.chinese)（少见写法）"
    }

    private static func detail(
        consonantClass: ConsonantClass,
        toneMark: ToneMark,
        ending: SyllableEnding,
        length: SyllableLength,
        tone: Tone,
        regular: Bool
    ) -> String {
        let klass = consonantClass.chinese
        switch toneMark {
        case .none:
            switch (consonantClass, ending, length) {
            case (.low, .dead, .short):
                return "\(klass)，没有声调符号，短死音节 → \(tone.chinese)。低辅音的死音节要看长短：短的是高调，长的是降调。中辅音和高辅音的死音节无论长短都是低调。"
            case (.low, .dead, .long):
                return "\(klass)，没有声调符号，长死音节 → \(tone.chinese)。同样是低辅音，如果元音改短，就会变成高调。มาก mâak 是长的，รัก rák 是短的。"
            case (_, .live, _):
                return "\(klass)，没有声调符号，活音节 → \(tone.chinese)。活音节是长开元音，或者韵尾是 ม น ง ย ว。"
            case (_, .dead, _):
                return "\(klass)，没有声调符号，死音节 → \(tone.chinese)。死音节以短元音或 p、t、k 收尾，韵尾不要读出元音。"
            }
        case .maiEk:
            return "\(klass) + ่（ไม้เอก）→ \(tone.chinese)。中辅音和高辅音读低调，低辅音读降调。有了符号，就不再看它是活音节还是死音节。"
        case .maiTho:
            return "\(klass) + ้（ไม้โท）→ \(tone.chinese)。中辅音和高辅音读降调，低辅音读高调。同样一个 ้，ข้าว 是降调，ร้อน 是高调，因为 ข 是高辅音、ร 是低辅音。"
        case .maiTri:
            if regular {
                return "中辅音 + ๊（ไม้ตรี）→ 高调。这个符号几乎只用在中辅音上，五个声调才能写全。"
            }
            return "๊（ไม้ตรี）写在\(klass)上不是常规拼写。如果硬读，一般仍读高调，但学习时先记住中辅音那一行。"
        case .maiChattawa:
            if regular {
                return "中辅音 + ๋（ไม้จัตวา）→ 升调。日常词里不多，เดี๋ยว dǐiao（等一下）是一个。"
            }
            return "๋（ไม้จัตวา）写在\(klass)上不是常规拼写。如果硬读，一般仍读升调。"
        }
    }
}

public enum RomanTone {
    /// 看罗马音里的 Paiboon 声调符号。一个音节只该有一个。
    public static func tone(in roman: String) -> Tone {
        let scalars = roman.decomposedStringWithCanonicalMapping.unicodeScalars
        if scalars.contains(Unicode.Scalar(0x030C)!) { return .rising }
        if scalars.contains(Unicode.Scalar(0x0302)!) { return .falling }
        if scalars.contains(Unicode.Scalar(0x0301)!) { return .high }
        if scalars.contains(Unicode.Scalar(0x0300)!) { return .low }
        return .mid
    }
}

public enum ThaiScriptMarks {
    /// 声调符号会和前面的辅音合成一个 Character，所以要看 Unicode 标量，不能看 Character。
    public static func toneMarks(in thai: String) -> [ToneMark] {
        thai.unicodeScalars.compactMap { scalar in
            switch scalar.value {
            case 0x0E48: return .maiEk
            case 0x0E49: return .maiTho
            case 0x0E4A: return .maiTri
            case 0x0E4B: return .maiChattawa
            default: return nil
            }
        }
    }
}

/// 44 个辅音的类。内容文件必须和这张表一致，改错一个测试就会失败。
public enum ThaiAlphabet {
    public static let entries: [(symbol: String, consonantClass: ConsonantClass, obsolete: Bool)] = [
        ("ก", .mid, false),
        ("ข", .high, false),
        ("ฃ", .high, true),
        ("ค", .low, false),
        ("ฅ", .low, true),
        ("ฆ", .low, false),
        ("ง", .low, false),
        ("จ", .mid, false),
        ("ฉ", .high, false),
        ("ช", .low, false),
        ("ซ", .low, false),
        ("ฌ", .low, false),
        ("ญ", .low, false),
        ("ฎ", .mid, false),
        ("ฏ", .mid, false),
        ("ฐ", .high, false),
        ("ฑ", .low, false),
        ("ฒ", .low, false),
        ("ณ", .low, false),
        ("ด", .mid, false),
        ("ต", .mid, false),
        ("ถ", .high, false),
        ("ท", .low, false),
        ("ธ", .low, false),
        ("น", .low, false),
        ("บ", .mid, false),
        ("ป", .mid, false),
        ("ผ", .high, false),
        ("ฝ", .high, false),
        ("พ", .low, false),
        ("ฟ", .low, false),
        ("ภ", .low, false),
        ("ม", .low, false),
        ("ย", .low, false),
        ("ร", .low, false),
        ("ล", .low, false),
        ("ว", .low, false),
        ("ศ", .high, false),
        ("ษ", .high, false),
        ("ส", .high, false),
        ("ห", .high, false),
        ("ฬ", .low, false),
        ("อ", .mid, false),
        ("ฮ", .low, false)
    ]
}

public enum RomanizationLegend {
    public static let summary = """
    声调符号和元音长短按 Paiboon：中调不标，低调 à，降调 â，高调 á，升调 ǎ。长元音写两遍（aa、ii、ʉʉ）。 \
    辅音把送气写成 h，方便对照普通话：ก k（像拼音 g）、ข/ค kh（像拼音 k）、ป bp（像拼音 b）、พ/ผ ph（像拼音 p）、ต dt（像拼音 d）、ท/ถ th（像拼音 t）。 \
    泰语另外还有真正浊的 บ b 和 ด d，普通话没有。 \
    Becker 原版 Paiboon 把 ก 写成 g、ข 写成 k，ครับ 会写成 kráp。这里写成 khráp，和例子 sà-wàt-dii khráp 一致。
    """
}
