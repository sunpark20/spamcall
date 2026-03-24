import Foundation

/// 번호대 그룹 (070, 080, 1588 등)
public struct PrefixGroup: Identifiable, Codable, Hashable {
    public let id: String
    public let displayName: String
    /// 국내 번호 접두사 (예: "070", "080", "1588")
    public let domesticPrefix: String
    /// 이 그룹의 하위 번호대 수 (예: 070은 10,000개 번호대)
    public let subPrefixCount: Int
    /// 번호대당 번호 수 (보통 10,000)
    public let numbersPerSubPrefix: Int

    public var totalNumbers: Int {
        subPrefixCount * numbersPerSubPrefix
    }

    public init(domesticPrefix: String, displayName: String, subPrefixCount: Int, numbersPerSubPrefix: Int = 10_000) {
        self.id = domesticPrefix
        self.displayName = displayName
        self.domesticPrefix = domesticPrefix
        self.subPrefixCount = subPrefixCount
        self.numbersPerSubPrefix = numbersPerSubPrefix
    }
}

extension PrefixGroup {
    /// 기본 제공 번호대 그룹 목록
    public static let defaultGroups: [PrefixGroup] = [
        PrefixGroup(domesticPrefix: "070", displayName: "070 (인터넷전화)", subPrefixCount: 10_000),
        PrefixGroup(domesticPrefix: "080", displayName: "080 (수신자부담)", subPrefixCount: 10_000),
        PrefixGroup(domesticPrefix: "050", displayName: "050 (개인안심번호)", subPrefixCount: 10_000),
        PrefixGroup(domesticPrefix: "1588", displayName: "1588 (대표번호)", subPrefixCount: 10, numbersPerSubPrefix: 10_000),
        PrefixGroup(domesticPrefix: "1577", displayName: "1577 (대표번호)", subPrefixCount: 10, numbersPerSubPrefix: 10_000),
        PrefixGroup(domesticPrefix: "1566", displayName: "1566 (대표번호)", subPrefixCount: 10, numbersPerSubPrefix: 10_000),
        PrefixGroup(domesticPrefix: "1544", displayName: "1544 (대표번호)", subPrefixCount: 10, numbersPerSubPrefix: 10_000),
        PrefixGroup(domesticPrefix: "1522", displayName: "1522 (대표번호)", subPrefixCount: 10, numbersPerSubPrefix: 10_000),
    ]
}
