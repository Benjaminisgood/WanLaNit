import Foundation
import ThaiLearnCore

struct ProgressStore {
    var fileURL: URL

    static func live() -> ProgressStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let directory = base.appendingPathComponent("WanLaNit", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return ProgressStore(fileURL: directory.appendingPathComponent("progress.json"))
    }

    func load() -> Progress {
        guard let data = try? Data(contentsOf: fileURL) else {
            return .fresh()
        }
        if let progress = try? JSONDecoder().decode(Progress.self, from: data) {
            return progress
        }
        let broken = fileURL.deletingLastPathComponent().appendingPathComponent("progress.unreadable.json")
        try? FileManager.default.removeItem(at: broken)
        try? FileManager.default.moveItem(at: fileURL, to: broken)
        return .fresh()
    }

    func save(_ progress: Progress) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(progress) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
