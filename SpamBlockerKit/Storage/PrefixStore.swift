import Foundation

/// 사용자의 번호대 선택 상태를 App Group UserDefaults에 저장/로드
public final class PrefixStore {
    public static let shared = PrefixStore()

    private let defaults: UserDefaults

    private init() {
        self.defaults = AppGroupManager.shared.sharedDefaults
    }

    /// 활성화된 prefix entry ID 목록 저장
    public func saveEnabledPrefixes(_ prefixIDs: Set<String>) {
        let array = Array(prefixIDs).sorted()
        defaults.set(array, forKey: SpamBlockerConstants.prefixStoreKey)
    }

    /// 활성화된 prefix entry ID 목록 로드
    public func loadEnabledPrefixes() -> Set<String> {
        let array = defaults.stringArray(forKey: SpamBlockerConstants.prefixStoreKey) ?? []
        return Set(array)
    }

    /// Extension 설정 저장
    public func saveExtensionConfig(_ config: ExtensionConfig) {
        if let data = try? JSONEncoder().encode(config) {
            defaults.set(data, forKey: SpamBlockerConstants.extensionConfigKey)
        }
    }

    /// Extension 설정 로드
    public func loadExtensionConfig() -> ExtensionConfig {
        guard let data = defaults.data(forKey: SpamBlockerConstants.extensionConfigKey),
              let config = try? JSONDecoder().decode(ExtensionConfig.self, from: data) else {
            return ExtensionConfig()
        }
        return config
    }

    /// 활성화된 PrefixEntry 목록 생성
    public func loadEnabledEntries() -> [PrefixEntry] {
        let enabledIDs = loadEnabledPrefixes()
        var entries: [PrefixEntry] = []

        for group in PrefixGroup.defaultGroups {
            for i in 0..<group.subPrefixCount {
                let entry = PrefixEntry(
                    groupPrefix: group.domesticPrefix,
                    subIndex: i,
                    numberCount: group.numbersPerSubPrefix
                )
                if enabledIDs.contains(entry.id) {
                    entries.append(entry)
                }
            }
        }

        return entries
    }
}
