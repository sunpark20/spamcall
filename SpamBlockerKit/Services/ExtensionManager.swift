import Foundation
import CallKit

/// Call Directory Extension 관리 (리로드, 상태 확인)
public final class ExtensionManager {
    public static let shared = ExtensionManager()

    private let manager = CXCallDirectoryManager.sharedInstance

    private init() {}

    /// Extension 활성화 상태 확인
    public func getEnabledStatus(
        for extensionID: String,
        completion: @escaping (CXCallDirectoryManager.EnabledStatus) -> Void
    ) {
        manager.getEnabledStatusForExtension(
            withIdentifier: extensionID
        ) { status, error in
            if let error = error {
                print("[ExtensionManager] Status check error for \(extensionID): \(error)")
                completion(.unknown)
                return
            }
            completion(status)
        }
    }

    /// Extension 리로드 요청
    public func reloadExtension(
        _ extensionID: String,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        manager.reloadExtension(
            withIdentifier: extensionID
        ) { error in
            if let error = error {
                print("[ExtensionManager] Reload error for \(extensionID): \(error)")
                completion(false, error)
            } else {
                print("[ExtensionManager] Reload success for \(extensionID)")
                completion(true, nil)
            }
        }
    }

    /// 모든 등록된 Extension 리로드
    public func reloadAllExtensions(completion: @escaping (Bool) -> Void) {
        let bundleIDs = SpamBlockerConstants.extensionBundleIDs
        var remaining = bundleIDs.count
        var allSuccess = true

        for bundleID in bundleIDs {
            reloadExtension(bundleID) { success, _ in
                if !success { allSuccess = false }
                remaining -= 1
                if remaining == 0 {
                    completion(allSuccess)
                }
            }
        }
    }
}
