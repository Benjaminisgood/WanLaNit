import Foundation

public struct ToneDrill: Equatable, Sendable, Identifiable {
    public var id: String
    public var consonantClass: ConsonantClass
    public var toneMark: ToneMark
    public var ending: SyllableEnding
    public var length: SyllableLength
    public var tone: Tone
    public var exampleThai: String?
    public var exampleRoman: String?
    public var exampleMeaning: String?

    public init(
        id: String,
        consonantClass: ConsonantClass,
        toneMark: ToneMark,
        ending: SyllableEnding,
        length: SyllableLength,
        tone: Tone,
        exampleThai: String?,
        exampleRoman: String?,
        exampleMeaning: String?
    ) {
        self.id = id
        self.consonantClass = consonantClass
        self.toneMark = toneMark
        self.ending = ending
        self.length = length
        self.tone = tone
        self.exampleThai = exampleThai
        self.exampleRoman = exampleRoman
        self.exampleMeaning = exampleMeaning
    }

    public var spoken: String? { exampleThai }
}

public enum ToneDrills {
    public static func all(in catalog: Catalog) -> [ToneDrill] {
        var drills: [ToneDrill] = []
        for consonantClass in ConsonantClass.allCases {
            for toneMark in [ToneMark.none, .maiEk, .maiTho, .maiTri, .maiChattawa] {
                guard ToneEngine.isRegular(consonantClass: consonantClass, toneMark: toneMark) else { continue }
                let shapes: [(SyllableEnding, SyllableLength)]
                if toneMark == .none {
                    shapes = [(.live, .long), (.dead, .short), (.dead, .long)]
                } else {
                    shapes = [(.live, .long)]
                }
                for (ending, length) in shapes {
                    let tone = ToneEngine.tone(
                        consonantClass: consonantClass,
                        toneMark: toneMark,
                        ending: ending,
                        length: length
                    )
                    let example = catalog.toneExamples(
                        consonantClass: consonantClass,
                        toneMark: toneMark,
                        ending: ending,
                        length: length,
                        limit: 1
                    ).first
                    let id = "tone-\(consonantClass.rawValue)-\(toneMark.rawValue)-\(ending.rawValue)-\(length.rawValue)"
                    drills.append(ToneDrill(
                        id: id,
                        consonantClass: consonantClass,
                        toneMark: toneMark,
                        ending: ending,
                        length: length,
                        tone: tone,
                        exampleThai: example?.syllableThai,
                        exampleRoman: example?.roman,
                        exampleMeaning: example?.meaning
                    ))
                }
            }
        }
        return drills
    }

    public static func drill(id: String, catalog: Catalog) -> ToneDrill? {
        all(in: catalog).first { $0.id == id }
    }
}
