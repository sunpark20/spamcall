import Foundation
import CallKit

@MainActor
final class ExtensionManager: ObservableObject {

    static let extensionCount = 58
    static let maxConcurrent = 1  // 확정: 순차 reload (2개 동시는 시간 단축 효과 없음)
    private static let bundlePrefix = "com.spamcall070.app.CallBlock"

    let bundleIDs: [String] = (0..<extensionCount).map {
        String(format: "%@%03d", bundlePrefix, $0)
    }

    @Published var enabledCount = 0
    @Published var statusChecked = false

    @Published var isReloading = false
    @Published var reloadProgress = 0
    @Published var reloadCurrent = ""
    @Published var reloadErrors: [(id: String, code: String, message: String)] = []
    @Published var reloadDuration: TimeInterval = 0
    @Published var isLoaded: Bool

    private let manager = CXCallDirectoryManager.sharedInstance
    private static let loadedKey = "reloadCompleted"
    private static let durationKey = "reloadDuration"

    init() {
        isLoaded = UserDefaults.standard.bool(forKey: Self.loadedKey)
        reloadDuration = UserDefaults.standard.double(forKey: Self.durationKey)
    }

    // MARK: - Status

    func refreshStatuses() {
        statusChecked = false
        enabledCount = 0

        Task {
            var count = 0
            for batch in stride(from: 0, to: bundleIDs.count, by: 10) {
                let end = min(batch + 10, bundleIDs.count)
                let slice = Array(bundleIDs[batch..<end])
                await withTaskGroup(of: Bool.self) { group in
                    for bid in slice {
                        group.addTask {
                            do {
                                let status = try await self.manager.enabledStatusForExtension(withIdentifier: bid)
                                return status == .enabled
                            } catch {
                                return false
                            }
                        }
                    }
                    for await isEnabled in group {
                        if isEnabled { count += 1 }
                    }
                }
                enabledCount = count
            }
            statusChecked = true
        }
    }

    // MARK: - Reload All

    func reloadAll() {
        guard !isReloading else { return }
        isReloading = true
        reloadProgress = 0
        reloadErrors = []
        reloadDuration = 0

        let startTime = Date()

        Task {
            await withTaskGroup(of: (String, Error?).self) { group in
                var pending = bundleIDs[...]
                var running = 0

                while !pending.isEmpty || running > 0 {
                    while running < Self.maxConcurrent, !pending.isEmpty {
                        let bid = pending.removeFirst()
                        running += 1
                        reloadCurrent = String(bid.suffix(3))
                        group.addTask {
                            do {
                                try await self.manager.reloadExtension(withIdentifier: bid)
                                return (bid, nil)
                            } catch {
                                return (bid, error)
                            }
                        }
                    }

                    if let result = await group.next() {
                        running -= 1
                        reloadProgress += 1
                        if let error = result.1 {
                            let (code, message) = Self.describeError(error)
                            reloadErrors.append((id: result.0, code: code, message: message))
                        }
                    }
                }
            }

            reloadDuration = Date().timeIntervalSince(startTime)
            reloadCurrent = ""
            isReloading = false

            if reloadErrors.isEmpty {
                isLoaded = true
                UserDefaults.standard.set(true, forKey: Self.loadedKey)
                UserDefaults.standard.set(reloadDuration, forKey: Self.durationKey)
            }

            refreshStatuses()
        }
    }

    // MARK: - Reload Failed

    func reloadFailed() {
        let failedIDs = reloadErrors.map(\.id)
        guard !failedIDs.isEmpty, !isReloading else { return }
        isReloading = true
        reloadProgress = 0
        reloadErrors = []
        reloadDuration = 0

        let startTime = Date()

        Task {
            for bid in failedIDs {
                do {
                    try await manager.reloadExtension(withIdentifier: bid)
                } catch {
                    let (code, message) = Self.describeError(error)
                    reloadErrors.append((id: bid, code: code, message: message))
                }
                reloadProgress += 1
            }

            reloadDuration = Date().timeIntervalSince(startTime)
            isReloading = false

            if reloadErrors.isEmpty {
                isLoaded = true
                UserDefaults.standard.set(true, forKey: Self.loadedKey)
                UserDefaults.standard.set(reloadDuration, forKey: Self.durationKey)
            }

            refreshStatuses()
        }
    }

    func markAsLoaded() {
        isLoaded = true
        UserDefaults.standard.set(true, forKey: Self.loadedKey)
    }

    func resetState() {
        reloadProgress = 0
        reloadErrors = []
        reloadDuration = 0
        isLoaded = false
        UserDefaults.standard.removeObject(forKey: Self.loadedKey)
        UserDefaults.standard.removeObject(forKey: Self.durationKey)
    }

    // MARK: - Error Report

    func generateReport() -> String {
        var lines: [String] = []
        lines.append("=== SpamCall070 에러 리포트 ===")
        lines.append("")

        // 기기
        lines.append("[기기]")
        var sysinfo = utsname()
        uname(&sysinfo)
        let machine = withUnsafePointer(to: &sysinfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
        lines.append("모델: \(machine)")
        let os = ProcessInfo.processInfo.operatingSystemVersion
        lines.append("iOS: \(os.majorVersion).\(os.minorVersion).\(os.patchVersion)")
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
           let total = attrs[.systemSize] as? Int64,
           let free = attrs[.systemFreeSize] as? Int64 {
            lines.append("저장공간: \(free / 1_000_000_000)GB / \(total / 1_000_000_000)GB")
        }
        lines.append("")

        // 익스텐션
        lines.append("[익스텐션]")
        lines.append("활성화: \(enabledCount) / \(Self.extensionCount)")
        if enabledCount < Self.extensionCount {
            let disabled = bundleIDs.enumerated().compactMap { i, _ in
                i < enabledCount ? nil : String(format: "Block %03d", i)
            }
            if !disabled.isEmpty {
                lines.append("미활성: \(disabled.prefix(10).joined(separator: ", "))")
            }
        }
        lines.append("")

        // Reload 결과
        lines.append("[Reload 결과]")
        let successCount = Self.extensionCount - reloadErrors.count
        lines.append("성공: \(successCount) / \(Self.extensionCount)")
        if !reloadErrors.isEmpty {
            lines.append("실패:")
            for error in reloadErrors {
                lines.append("  Block \(error.id.suffix(3)) — \(error.code): \(error.message)")
            }
        }
        if reloadDuration > 0 {
            let minutes = Int(reloadDuration) / 60
            let seconds = Int(reloadDuration) % 60
            lines.append("소요: \(minutes)분 \(seconds)초")
        }
        lines.append("")

        // 앱 상태
        lines.append("[앱 상태]")
        lines.append("로딩 완료: \(isLoaded)")
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            lines.append("버전: \(version) (\(build))")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Error Report Submission

    private static let webhookURL = "https://script.google.com/macros/s/AKfycbyOBS9hkGJNbLPDVhqPyn45lPfcs70CgFoPWPAW-ggR1o9ZTybvCb3lBpGslbfFo1sqBA/exec"

    func submitReport() async -> Bool {
        let report = generateReport()
        let errorSummary: String
        if reloadErrors.isEmpty {
            errorSummary = "수동 신고"
        } else {
            errorSummary = "\(reloadErrors.count)개 실패"
        }

        let os = ProcessInfo.processInfo.operatingSystemVersion
        var sysinfo = utsname()
        uname(&sysinfo)
        let machine = withUnsafePointer(to: &sysinfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }

        let payload: [String: String] = [
            "app_name": "SpamCall070",
            "ios_version": "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)",
            "device_model": machine,
            "error_summary": errorSummary,
            "full_report": report
        ]

        guard let url = URL(string: Self.webhookURL),
              let body = try? JSONSerialization.data(withJSONObject: payload) else {
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        request.timeoutInterval = 10

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    // MARK: - Error Description

    private static func describeError(_ error: Error) -> (code: String, message: String) {
        let nsError = error as NSError

        // CXErrorCodeCallDirectoryManagerError domain
        if nsError.domain == "com.apple.CallKit.error.calldirectorymanager" {
            switch nsError.code {
            case 0: // unknown
                return ("unknown", "알 수 없는 오류. 기기를 재시작해 보세요.")
            case 1: // noExtensionFound
                return ("noExtensionFound", "익스텐션을 찾을 수 없음. 앱을 재설치해 주세요.")
            case 2: // loadingInterrupted
                return ("loadingInterrupted", "로딩 중단됨. 다시 시도해 주세요.")
            case 3: // entriesOutOfOrder
                return ("entriesOutOfOrder", "내부 오류 (번호 순서). 개발자에게 문의해 주세요.")
            case 4: // duplicateEntries
                return ("duplicateEntries", "내부 오류 (중복). 개발자에게 문의해 주세요.")
            case 5: // maximumEntriesExceeded
                return ("maximumEntriesExceeded", "등록 한도 초과. 개발자에게 문의해 주세요.")
            case 6: // extensionDisabled
                return ("extensionDisabled", "설정에서 꺼져 있습니다. 설정에서 켜주세요.")
            case 7: // currentlyLoading
                return ("currentlyLoading", "이미 로딩 중. 잠시 후 다시 시도해 주세요.")
            case 8: // unexpectedIncrementalRemoval
                return ("unexpectedIncrementalRemoval", "설정에서 OFF→ON 후 다시 시도해 주세요.")
            default:
                return ("code\(nsError.code)", "오류 코드 \(nsError.code). 기기를 재시작해 보세요.")
            }
        }

        // SQLite 에러
        if nsError.domain == "com.apple.callkit.database.sqlite" {
            if nsError.code == 19 {
                return ("sqlite:19", "DB 충돌. 앱 삭제 → 기기 재시작 → 앱 재설치 후 다시 시도해 주세요.")
            }
            return ("sqlite:\(nsError.code)", "DB 오류 \(nsError.code). 앱 삭제 → 기기 재시작 → 앱 재설치 후 다시 시도해 주세요.")
        }

        return ("other:\(nsError.code)", "\(nsError.domain):\(nsError.code) — 기기를 재시작해 보세요.")
    }
}
