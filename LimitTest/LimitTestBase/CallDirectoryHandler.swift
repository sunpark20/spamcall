import Foundation
import CallKit

class CallDirectoryHandler: CXCallDirectoryProvider {

    private static let rangeBase: CXCallDirectoryPhoneNumber = 827_000_000_000
    private static let totalNumbers: CXCallDirectoryPhoneNumber = 100_000_000
    private static let testPhoneNumber: CXCallDirectoryPhoneNumber = 821_065_728_791
    private static let perExtension: CXCallDirectoryPhoneNumber = 1_750_000

    private var sliceIndex: Int? {
        guard let bundleID = Bundle.main.bundleIdentifier,
              let last = bundleID.split(separator: ".").last else { return nil }
        return Int(last.replacingOccurrences(of: "LimitTestExt", with: ""))
    }

    override func beginRequest(with context: CXCallDirectoryExtensionContext) {
        context.delegate = self

        guard let index = sliceIndex else {
            context.cancelRequest(withError: NSError(domain: "CDH", code: 1))
            return
        }

        // 비증분 (Settings 토글 시) → 아무것도 등록 안 함 → 즉시 완료
        if !context.isIncremental {
            context.completeRequest()
            return
        }

        // 증분 (앱의 reloadExtension 호출 시) → 자기 슬라이스 등록
        let start = Self.rangeBase + CXCallDirectoryPhoneNumber(index) * Self.perExtension
        let end = min(start + Self.perExtension, Self.rangeBase + Self.totalNumbers)

        if start >= end {
            context.completeRequest()
            return
        }

        // Ext049에 테스트 번호 포함
        if index == 57 {
            context.addBlockingEntry(withNextSequentialPhoneNumber: Self.testPhoneNumber)
        }

        for number in start..<end {
            context.addBlockingEntry(withNextSequentialPhoneNumber: number)
        }

        context.completeRequest()
    }
}

extension CallDirectoryHandler: CXCallDirectoryExtensionContextDelegate {
    func requestFailed(for extensionContext: CXCallDirectoryExtensionContext, withError error: any Error) {}
}
