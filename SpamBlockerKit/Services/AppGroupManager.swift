import Foundation

/// App Group을 통한 메인앱 ↔ Extension 간 데이터 공유 관리
public final class AppGroupManager {
    public static let shared = AppGroupManager()

    public let sharedDefaults: UserDefaults
    public let containerURL: URL

    private init() {
        guard let defaults = UserDefaults(suiteName: SpamBlockerConstants.appGroupID) else {
            fatalError("App Group '\(SpamBlockerConstants.appGroupID)' not configured")
        }
        guard let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: SpamBlockerConstants.appGroupID
        ) else {
            fatalError("App Group container not available")
        }
        self.sharedDefaults = defaults
        self.containerURL = url
    }

    /// Extension별 바이너리 파일 경로
    public func binaryFilePath(for extensionIndex: Int) -> URL {
        containerURL.appendingPathComponent(
            "\(SpamBlockerConstants.binaryFilePrefix)_\(extensionIndex).bin"
        )
    }

    /// 기본(단일 Extension) 바이너리 파일 경로
    public var defaultBinaryFilePath: URL {
        binaryFilePath(for: 0)
    }
}
