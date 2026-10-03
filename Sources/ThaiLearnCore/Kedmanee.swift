import Foundation

public enum TypingFinger: String, Codable, Sendable {
    case leftPinky
    case leftRing
    case leftMiddle
    case leftIndex
    case rightIndex
    case rightMiddle
    case rightRing
    case rightPinky
    case thumb

    public var chinese: String {
        switch self {
        case .leftPinky: return "左小指"
        case .leftRing: return "左无名指"
        case .leftMiddle: return "左中指"
        case .leftIndex: return "左食指"
        case .rightIndex: return "右食指"
        case .rightMiddle: return "右中指"
        case .rightRing: return "右无名指"
        case .rightPinky: return "右小指"
        case .thumb: return "拇指"
        }
    }
}

public enum TypingRow: String, Codable, Hashable, Sendable {
    case number
    case upper
    case home
    case lower
}

/// One physical key on the Thai Kedmanee layout used by macOS.
public struct KedmaneeKey: Equatable, Identifiable, Sendable {
    /// Character a US keyboard inserts when this key is pressed unshifted.
    public var usPlain: String
    /// Character a US keyboard inserts when this key is pressed with Shift.
    public var usShift: String
    public var plain: String
    public var shifted: String
    public var finger: TypingFinger
    public var row: TypingRow
    public var homeBump: Bool

    public var id: String { usPlain }

    public init(
        usPlain: String,
        usShift: String,
        plain: String,
        shifted: String,
        finger: TypingFinger,
        row: TypingRow,
        homeBump: Bool = false
    ) {
        self.usPlain = usPlain
        self.usShift = usShift
        self.plain = plain
        self.shifted = shifted
        self.finger = finger
        self.row = row
        self.homeBump = homeBump
    }

    public var plainLabel: String { KedmaneeKeyboard.label(for: plain) }
    public var shiftedLabel: String { KedmaneeKeyboard.label(for: shifted) }
}

public enum KedmaneeKeyboard {
    public static let keys: [KedmaneeKey] = [
        key("`", "~", "_", "%", .leftPinky, .number),
        key("1", "!", "ๅ", "+", .leftPinky, .number),
        key("2", "@", "/", "๑", .leftRing, .number),
        key("3", "#", "-", "๒", .leftMiddle, .number),
        key("4", "$", "ภ", "๓", .leftIndex, .number),
        key("5", "%", "ถ", "๔", .leftIndex, .number),
        key("6", "^", "ุ", "ู", .rightIndex, .number),
        key("7", "&", "ึ", "฿", .rightIndex, .number),
        key("8", "*", "ค", "๕", .rightMiddle, .number),
        key("9", "(", "ต", "๖", .rightRing, .number),
        key("0", ")", "จ", "๗", .rightPinky, .number),
        key("-", "_", "ข", "๘", .rightPinky, .number),
        key("=", "+", "ช", "๙", .rightPinky, .number),

        key("q", "Q", "ๆ", "๐", .leftPinky, .upper),
        key("w", "W", "ไ", "\"", .leftRing, .upper),
        key("e", "E", "ำ", "ฎ", .leftMiddle, .upper),
        key("r", "R", "พ", "ฑ", .leftIndex, .upper),
        key("t", "T", "ะ", "ธ", .leftIndex, .upper),
        key("y", "Y", "ั", "ํ", .rightIndex, .upper),
        key("u", "U", "ี", "๊", .rightIndex, .upper),
        key("i", "I", "ร", "ณ", .rightMiddle, .upper),
        key("o", "O", "น", "ฯ", .rightRing, .upper),
        key("p", "P", "ย", "ญ", .rightPinky, .upper),
        key("[", "{", "บ", "ฐ", .rightPinky, .upper),
        key("]", "}", "ล", ",", .rightPinky, .upper),
        key("\\", "|", "ฃ", "ฅ", .rightPinky, .upper),

        key("a", "A", "ฟ", "ฤ", .leftPinky, .home),
        key("s", "S", "ห", "ฆ", .leftRing, .home),
        key("d", "D", "ก", "ฏ", .leftMiddle, .home),
        key("f", "F", "ด", "โ", .leftIndex, .home, bump: true),
        key("g", "G", "เ", "ฌ", .leftIndex, .home),
        key("h", "H", "้", "็", .rightIndex, .home),
        key("j", "J", "่", "๋", .rightIndex, .home, bump: true),
        key("k", "K", "า", "ษ", .rightMiddle, .home),
        key("l", "L", "ส", "ศ", .rightRing, .home),
        key(";", ":", "ว", "ซ", .rightPinky, .home),
        key("'", "\"", "ง", ".", .rightPinky, .home),

        key("z", "Z", "ผ", "(", .leftPinky, .lower),
        key("x", "X", "ป", ")", .leftRing, .lower),
        key("c", "C", "แ", "ฉ", .leftMiddle, .lower),
        key("v", "V", "อ", "ฮ", .leftIndex, .lower),
        key("b", "B", "ิ", "ฺ", .leftIndex, .lower),
        key("n", "N", "ื", "์", .rightIndex, .lower),
        key("m", "M", "ท", "?", .rightIndex, .lower),
        key(",", "<", "ม", "ฒ", .rightMiddle, .lower),
        key(".", ">", "ใ", "ฬ", .rightRing, .lower),
        key("/", "?", "ฝ", "ฦ", .rightPinky, .lower)
    ]

    public static let rowOrder: [TypingRow] = [.number, .upper, .home, .lower]

    public static func key(_ usPlain: String) -> KedmaneeKey? {
        keys.first { $0.usPlain == usPlain }
    }

    public static func keys(in row: TypingRow) -> [KedmaneeKey] {
        keys.filter { $0.row == row }
    }

    /// Which key produces this Thai scalar, and whether Shift is held.
    public static func producer(of scalar: String) -> (key: KedmaneeKey, shifted: Bool)? {
        for item in keys {
            if item.plain == scalar { return (item, false) }
            if item.shifted == scalar { return (item, true) }
        }
        return nil
    }

    public static func isCombiningMark(_ text: String) -> Bool {
        guard let value = text.unicodeScalars.first?.value, text.unicodeScalars.count == 1 else { return false }
        return value == 0x0E31 || (0x0E34...0x0E3A).contains(value) || (0x0E47...0x0E4E).contains(value)
    }

    public static func label(for text: String) -> String {
        isCombiningMark(text) ? "◌\(text)" : text
    }

    private static func key(
        _ usPlain: String,
        _ usShift: String,
        _ plain: String,
        _ shifted: String,
        _ finger: TypingFinger,
        _ row: TypingRow,
        bump: Bool = false
    ) -> KedmaneeKey {
        KedmaneeKey(
            usPlain: usPlain,
            usShift: usShift,
            plain: plain,
            shifted: shifted,
            finger: finger,
            row: row,
            homeBump: bump
        )
    }
}

public enum TypingInput {
    /// Map characters produced by a US QWERTY keyboard onto Kedmanee.
    /// Characters that are already Thai, and spaces, stay as they are.
    /// Shift+M on a US keyboard inserts "M", which becomes "?".
    /// The US "?" key is Shift+/, which becomes ฦ.
    public static func thai(fromQWERTY raw: String) -> String {
        let table = qwertyMap
        var out = ""
        for scalar in raw.unicodeScalars {
            let piece = String(scalar)
            if piece == " " || piece == "\n" {
                out.append(piece)
            } else if let mapped = table[piece] {
                out.append(mapped)
            } else {
                out.append(piece)
            }
        }
        return out
    }

    static let qwertyMap: [String: String] = {
        var table: [String: String] = [:]
        for item in KedmaneeKeyboard.keys {
            table[item.usPlain] = item.plain
            table[item.usShift] = item.shifted
        }
        return table
    }()
}
