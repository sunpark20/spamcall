import Foundation

/// Extension별 담당 번호대 설정
public struct ExtensionConfig: Codable {
    /// Extension bundle ID → 담당 prefix entry ID 배열
    public var assignments: [String: [String]]

    public init(assignments: [String: [String]] = [:]) {
        self.assignments = assignments
    }

    /// 단일 Extension에 모든 번호대를 할당 (Phase 0 기본)
    public static func singleExtension(prefixIDs: [String]) -> ExtensionConfig {
        let bundleID = SpamBlockerConstants.extensionBundleIDs[0]
        return ExtensionConfig(assignments: [bundleID: prefixIDs])
    }

    /// 특정 Extension에 할당된 prefix ID 목록
    public func prefixIDs(for bundleID: String) -> [String] {
        assignments[bundleID] ?? []
    }
}
