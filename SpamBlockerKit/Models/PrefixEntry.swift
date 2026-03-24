import Foundation

/// 개별 번호대 항목 (예: "070-0001")
public struct PrefixEntry: Identifiable, Codable, Hashable {
    public let id: String
    /// 소속 그룹의 domestic prefix (예: "070")
    public let groupPrefix: String
    /// 하위 번호대 인덱스 (예: 0001)
    public let subIndex: Int
    /// 이 번호대의 번호 수
    public let numberCount: Int

    /// 표시용 이름 (예: "070-0001")
    public var displayName: String {
        if groupPrefix.count <= 3 {
            return String(format: "%@-%04d", groupPrefix, subIndex)
        } else {
            return String(format: "%@-%d", groupPrefix, subIndex)
        }
    }

    /// E.164 형식의 시작 번호 (Int64)
    /// 예: 070-0001-0000 → +82700010000 → 82700010000
    public var startNumber: Int64 {
        let domestic = domesticFullNumber(suffix: 0)
        return Self.toE164(domestic: domestic)
    }

    /// E.164 형식의 끝 번호 (Int64)
    public var endNumber: Int64 {
        let domestic = domesticFullNumber(suffix: numberCount - 1)
        return Self.toE164(domestic: domestic)
    }

    public init(groupPrefix: String, subIndex: Int, numberCount: Int = 10_000) {
        self.groupPrefix = groupPrefix
        self.subIndex = subIndex
        self.numberCount = numberCount
        self.id = "\(groupPrefix)-\(subIndex)"
    }

    /// 국내 전체 번호 문자열 생성 (예: "07000010000")
    private func domesticFullNumber(suffix: Int) -> String {
        if groupPrefix.count <= 3 {
            // 070, 080, 050 등: 070-XXXX-YYYY 형태 (11자리)
            return String(format: "%@%04d%04d", groupPrefix, subIndex, suffix)
        } else {
            // 1588 등: 1588-X-YYYY 형태
            return String(format: "%@%d%04d", groupPrefix, subIndex, suffix)
        }
    }

    /// 국내번호 문자열을 E.164 Int64로 변환
    /// "07000010000" → 82 + "7000010000" (앞의 0 제거) → 827000010000
    static func toE164(domestic: String) -> Int64 {
        var digits = domestic
        // 국내번호 앞의 0 제거 (070 → 70, 080 → 80)
        if digits.hasPrefix("0") {
            digits = String(digits.dropFirst())
        }
        let e164String = "82\(digits)"
        return Int64(e164String) ?? 0
    }
}
