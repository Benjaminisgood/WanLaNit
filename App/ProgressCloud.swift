import Foundation

/// iCloud 同步默认不编译进去。付费开发者账号打开 WANLANIT_ICLOUD 之后才会读写钥匙值存储。
enum ProgressCloud {
    static var enabled: Bool {
        #if WANLANIT_ICLOUD
        true
        #else
        false
        #endif
    }

    static var note: String {
        "iCloud 默认为关。导出的 JSON 用免费 Apple ID 就能在两台设备之间拷。要开同步，需要付费的开发者账号、iCloud 能力，以及编译条件 WANLANIT_ICLOUD。"
    }

    static func push(_ data: Data) {
        #if WANLANIT_ICLOUD
        guard data.count < 900_000 else { return }
        let store = NSUbiquitousKeyValueStore.default
        store.set(data, forKey: "wanlanit.progress")
        store.synchronize()
        #endif
    }
}
