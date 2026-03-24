import Foundation

public enum SpamBlockerConstants {
    public static let appGroupID = "group.com.spamblocker.shared"

    public static let extensionBundleIDs = [
        "com.spamblocker.app.calldirectory1"
    ]

    public static let binaryFilePrefix = "blocked_numbers"
    public static let prefixStoreKey = "enabled_prefixes"
    public static let extensionConfigKey = "extension_config"

    /// 한국 국가코드 (E.164 형식에서 사용)
    public static let koreaCountryCode: Int64 = 82
}
