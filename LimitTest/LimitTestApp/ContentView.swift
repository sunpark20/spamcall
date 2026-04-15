import SwiftUI
import CallKit

struct ContentView: View {

    private static let appGroupID = "group.com.sunguk.spamcall"
    private static let bundlePrefix = "com.limittest50.app.LimitTestExt"

    // MARK: - State

    // Phase 0-A: 익스텐션당 한도 K 탐색
    @State private var perExtension: Int = 1_000_000
    @State private var perExtensionText: String = "1000000"

    // Phase 0-B: 시스템 전체 한도 탐색
    @State private var activeExtensionCount: Int = 1
    @State private var activeCountText: String = "1"

    // 테스트 번호 포함 여부
    @State private var includeTestNumber: Bool = true

    // Reload 상태
    @State private var isReloading: Bool = false
    @State private var reloadProgress: Int = 0
    @State private var reloadTotal: Int = 0
    @State private var reloadErrors: [String] = []
    @State private var reloadDuration: TimeInterval = 0

    // 자동 반복 상태
    @State private var autoReloadCount: Int = 0  // 완료된 반복 횟수
    @State private var autoReloadTarget: Int = 0 // 목표 횟수
    @State private var isAutoReloading: Bool = false

    // 증분 누적 상태
    @State private var accumulatedEntries: Int = 0
    private let perReload: Int = 1_750_000  // CallDirectoryHandler와 동일

    // 익스텐션 상태
    @State private var enabledCount: Int = 0
    @State private var statusChecked: Bool = false
    @State private var statusCheckProgress: Int = 0

    var body: some View {
        NavigationStack {
            Form {
                configSection
                statusSection
                reloadSection
                resultSection
                infoSection
            }
            .navigationTitle("LimitTest")
        }
        .onAppear {
            refreshStatuses()
            loadAccumulated()
        }
    }

    // MARK: - Config Section

    private var configSection: some View {
        Section("설정") {
            VStack(alignment: .leading, spacing: 8) {
                Text("익스텐션당 등록 건수 (K)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("K", text: $perExtensionText)
                    .keyboardType(.numberPad)
                    .onChange(of: perExtensionText) { newValue in
                        if let val = Int(newValue), val > 0 {
                            perExtension = val
                        }
                    }
                HStack {
                    quickButton("100만", 1_000_000)
                    quickButton("125만", 1_250_000)
                    quickButton("150만", 1_500_000)
                    quickButton("175만", 1_750_000)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("활성 익스텐션 수 (N)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("N", text: $activeCountText)
                    .keyboardType(.numberPad)
                    .onChange(of: activeCountText) { newValue in
                        if let val = Int(newValue), val > 0, val <= 100 {
                            activeExtensionCount = val
                        }
                    }
                HStack {
                    quickCountButton("1", 1)
                    quickCountButton("20", 20)
                    quickCountButton("50", 50)
                    quickCountButton("100", 100)
                }
            }

            Toggle("010 테스트 번호 포함", isOn: $includeTestNumber)

            Text("총 등록 번호: \(totalNumbersFormatted)")
                .font(.headline)
                .monospacedDigit()
        }
    }

    // MARK: - Status Section

    private var statusSection: some View {
        Section("익스텐션 상태") {
            if statusChecked {
                Text("활성화: \(enabledCount) / 100")
                    .monospacedDigit()
            } else {
                Text("확인 중... (\(statusCheckProgress)/100)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Button("전화 차단 및 발신자 확인 열기") {
                openCallBlockingSettings()
            }
            if #available(iOS 18, *) {
                Text("설정 > 앱 > 전화 > 전화 차단 및 발신자 확인")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("설정 > 전화 > 전화 차단 및 발신자 확인")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button("상태 새로고침") {
                refreshStatuses()
            }
        }
    }

    // MARK: - Reload Section

    @ViewBuilder
    private var reloadSection: some View {
        Section("누적 상태") {
            Text("현재 누적: \(accumulatedFormatted)")
                .font(.headline)
                .monospacedDigit()
            Text("목표: 1억 (100,000,000) / 1회 +\(perReload)개")
                .font(.caption)
                .foregroundStyle(.secondary)
            ProgressView(value: Double(accumulatedEntries), total: 100_000_000)
            Button("오프셋 초기화") {
                if let defaults = UserDefaults(suiteName: Self.appGroupID) {
                    for i in 0..<100 { defaults.removeObject(forKey: "offset_\(i)") }
                    defaults.synchronize()
                    accumulatedEntries = 0
                }
            }
            .font(.caption)
            .foregroundStyle(.red)
            Text("DB 초기화: Settings에서 익스텐션 OFF→ON")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }

        Section("자동 Reload") {
            if isAutoReloading {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        ProgressView()
                        Text("자동 진행 중: \(autoReloadCount) / \(autoReloadTarget)회")
                            .monospacedDigit()
                    }
                    Text("누적: \(accumulatedFormatted)")
                        .font(.caption)
                        .monospacedDigit()
                    Button("중지") {
                        isAutoReloading = false
                    }
                    .foregroundStyle(.red)
                }
            } else {
                Button("1억까지 자동 Reload 시작") {
                    startAutoReload(target: 100_000_000)
                }
                .disabled(isReloading)
                Button("1000만까지 테스트") {
                    startAutoReload(target: 10_000_000)
                }
                .font(.caption)
                .disabled(isReloading)

                Button("최종 차단 검증 (Ext057에 010 번호 포함)") {
                    verifyBlocking()
                }
                .font(.caption)
                .foregroundStyle(.orange)
                .disabled(isReloading || isAutoReloading)
            }
        }
    }

    // MARK: - Result Section

    private var resultSection: some View {
        Section("결과") {
            if reloadDuration > 0 {
                Text("소요 시간: \(String(format: "%.1f", reloadDuration))초")
                    .monospacedDigit()
            }
            if reloadErrors.isEmpty && reloadProgress > 0 && !isReloading {
                Text("전체 성공")
                    .foregroundStyle(.green)
            }
            if !reloadErrors.isEmpty {
                Text("\(reloadErrors.count)개 실패")
                    .foregroundStyle(.red)
                ForEach(reloadErrors, id: \.self) { error in
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        Section("테스트 안내") {
            Text("""
            Phase 0-A: K 이진 탐색
            1. N=1로 고정
            2. K를 조절하며 reload
            3. 성공하는 최대 K를 찾기

            Phase 0-B: 시스템 전체 한도
            1. K를 확정값으로 고정
            2. N을 20→40→60→80→100 증가
            3. 매 단계마다 010에서 전화 걸어 차단 확인

            테스트 번호: 010-6572-8791
            → 차단 확인: 이 번호에서 전화 걸기
            → 차단되면 수신 화면 안 뜸
            """)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private var accumulatedFormatted: String {
        if accumulatedEntries >= 1_000_000 {
            return "\(accumulatedEntries / 1_000_000)백만 (\(accumulatedEntries))"
        }
        return "\(accumulatedEntries)"
    }

    private var totalNumbersFormatted: String {
        let total = Int64(perExtension) * Int64(activeExtensionCount)
        if total >= 100_000_000 {
            return "\(total / 1_000_000)백만 (\(total))"
        } else if total >= 1_000_000 {
            return "\(total / 1_000_000)백만 (\(total))"
        } else {
            return "\(total)"
        }
    }

    private func quickButton(_ label: String, _ value: Int) -> some View {
        Button(label) {
            perExtension = value
            perExtensionText = "\(value)"
        }
        .buttonStyle(.bordered)
        .font(.caption)
    }

    private func quickCountButton(_ label: String, _ value: Int) -> some View {
        Button(label) {
            activeExtensionCount = value
            activeCountText = "\(value)"
        }
        .buttonStyle(.bordered)
        .font(.caption)
    }

    // MARK: - Accumulated

    private func loadAccumulated() {
        let defaults = UserDefaults(suiteName: Self.appGroupID)
        let offset = defaults?.integer(forKey: "offset_0") ?? 0
        accumulatedEntries = offset
    }

    private func resetAll() {
        guard let defaults = UserDefaults(suiteName: Self.appGroupID) else { return }
        // 1. 리셋 모드 ON + 오프셋 초기화
        defaults.set(true, forKey: "resetMode")
        for i in 0..<100 { defaults.removeObject(forKey: "offset_\(i)") }
        defaults.synchronize()
        accumulatedEntries = 0

        // 2. 활성화된 익스텐션 reload (시스템 DB 비우기)
        isReloading = true
        reloadProgress = 0
        reloadErrors = []
        let manager = CXCallDirectoryManager.sharedInstance
        let prefix = Self.bundlePrefix

        Task {
            // 활성화된 것만 reload
            var enabled: [Int] = []
            await withTaskGroup(of: (Int, Bool).self) { group in
                for i in 0..<100 {
                    group.addTask {
                        let bid = String(format: "%@%03d", prefix, i)
                        do {
                            let s = try await manager.enabledStatusForExtension(withIdentifier: bid)
                            return (i, s == .enabled)
                        } catch { return (i, false) }
                    }
                }
                for await r in group { if r.1 { enabled.append(r.0) } }
            }

            await MainActor.run { reloadTotal = enabled.count }

            for idx in enabled {
                let bid = String(format: "%@%03d", prefix, idx)
                do {
                    try await manager.reloadExtension(withIdentifier: bid)
                } catch {}
                await MainActor.run { reloadProgress += 1 }
            }

            // 3. 리셋 모드 OFF
            await MainActor.run {
                defaults.set(false, forKey: "resetMode")
                defaults.synchronize()
                isReloading = false
                accumulatedEntries = 0
            }
        }
    }

    private func verifyBlocking() {
        let manager = CXCallDirectoryManager.sharedInstance
        let bundleID = String(format: "%@%03d", Self.bundlePrefix, 57) // Ext057 (테스트 번호 포함)

        Task {
            do {
                try await manager.reloadExtension(withIdentifier: bundleID)
                await MainActor.run {
                    reloadErrors = []
                    reloadErrors.append("✅ Ext001 reload 성공 — 010-6572-8791로 전화 걸어 차단 확인하세요")
                }
            } catch {
                await MainActor.run {
                    reloadErrors = ["❌ Ext001 실패: \(error.localizedDescription)"]
                }
            }
        }
    }

    private func startAutoReload(target: Int) {
        isAutoReloading = true
        autoReloadCount = 0
        reloadErrors = []
        reloadDuration = 0

        let startTime = Date()
        let manager = CXCallDirectoryManager.sharedInstance
        let prefix = Self.bundlePrefix

        Task {
            // 활성화된 익스텐션 파악 (Ext001=테스트용 제외)
            var enabled: [Int] = []
            await withTaskGroup(of: (Int, Bool).self) { group in
                for i in 0..<100 {
                    // 모든 익스텐션 체크 (Ext000~Ext049가 070 담당)
                    group.addTask {
                        let bid = String(format: "%@%03d", prefix, i)
                        do {
                            let s = try await manager.enabledStatusForExtension(withIdentifier: bid)
                            return (i, s == .enabled)
                        } catch { return (i, false) }
                    }
                }
                for await r in group { if r.1 { enabled.append(r.0) } }
            }
            enabled.sort()

            // 목표 달성에 필요한 익스텐션 수
            let needed = (target + perReload - 1) / perReload
            let toReload = Array(enabled.prefix(needed))

            await MainActor.run {
                autoReloadTarget = toReload.count
                accumulatedEntries = 0
            }

            // 순차 reload: 플래그 ON → reload → 완료
            let defaults = UserDefaults(suiteName: Self.appGroupID)
            for (i, idx) in toReload.enumerated() {
                if !isAutoReloading { break }

                // 플래그 ON → 익스텐션이 번호를 등록하게 함
                defaults?.set(true, forKey: "load_\(idx)")
                defaults?.synchronize()

                let bid = String(format: "%@%03d", prefix, idx)
                do {
                    try await manager.reloadExtension(withIdentifier: bid)
                    await MainActor.run {
                        autoReloadCount = i + 1
                        accumulatedEntries = (i + 1) * perReload
                    }
                } catch {
                    await MainActor.run {
                        reloadErrors.append(String(format: "Ext%03d: %@", idx, error.localizedDescription))
                        // 에러 나도 계속 진행 (이미 로드된 익스텐션은 건너뜀)
                    }
                }
            }

            await MainActor.run {
                reloadDuration = Date().timeIntervalSince(startTime)
                isAutoReloading = false
            }
        }
    }

    private func incrementOffset(for index: Int) {
        guard let defaults = UserDefaults(suiteName: Self.appGroupID) else { return }
        let key = "offset_\(index)"
        let current = defaults.integer(forKey: key)
        let newOffset = current + perExtension
        defaults.set(newOffset, forKey: key)
        defaults.synchronize()
        if index == 0 {
            accumulatedEntries = newOffset
        }
    }

    // MARK: - Settings Navigation

    private func openCallBlockingSettings() {
        // iOS 버전별 후보 URL (순서대로 시도)
        let candidates = [
            // iOS 26+ (Settings 재구성)
            "App-prefs:com.apple.mobilephone&path=CALL_BLOCKING_AND_IDENTIFICATION",
            "App-prefs:com.apple.mobilephone",
            "prefs:root=Apps&path=com.apple.mobilephone",
            // iOS 18+
            "App-prefs:Phone&path=CALL_BLOCKING_AND_IDENTIFICATION",
            "App-prefs:Phone",
            // iOS 16-17
            "prefs:root=Phone",
        ]
        for urlString in candidates {
            if let url = URL(string: urlString) {
                UIApplication.shared.open(url) { success in
                    if success { return }
                }
                return
            }
        }
    }

    // MARK: - Actions

    private func saveSettings() {
        guard let defaults = UserDefaults(suiteName: Self.appGroupID) else { return }
        defaults.set(perExtension, forKey: "perExtension")
        defaults.set(activeExtensionCount, forKey: "activeExtensionCount")
        defaults.set(includeTestNumber, forKey: "includeTestNumber")
        defaults.synchronize()
    }

    private func startReload() {
        saveSettings()
        isReloading = true
        reloadProgress = 0
        reloadErrors = []
        reloadDuration = 0

        let startTime = Date()
        let manager = CXCallDirectoryManager.sharedInstance
        let prefix = Self.bundlePrefix

        Task {
            // 먼저 활성화된 익스텐션만 파악
            var enabledIndices: [Int] = []
            await withTaskGroup(of: (Int, Bool).self) { group in
                for i in 0..<100 {
                    group.addTask {
                        let bundleID = String(format: "%@%03d", prefix, i)
                        do {
                            let status = try await manager.enabledStatusForExtension(withIdentifier: bundleID)
                            return (i, status == .enabled)
                        } catch {
                            return (i, false)
                        }
                    }
                }
                for await result in group {
                    if result.1 {
                        enabledIndices.append(result.0)
                    }
                }
            }
            enabledIndices.sort()

            await MainActor.run {
                reloadTotal = enabledIndices.count
                // activeExtensionCount를 실제 활성화 수로 갱신하여 저장
                activeExtensionCount = enabledIndices.count
                activeCountText = "\(enabledIndices.count)"
                saveSettings()
            }

            // 활성화된 익스텐션만 reload (동시 5개)
            await withTaskGroup(of: (Int, Error?).self) { group in
                var pending = enabledIndices
                var running = 0
                let maxConcurrent = 5

                while !pending.isEmpty || running > 0 {
                    while running < maxConcurrent && !pending.isEmpty {
                        let idx = pending.removeFirst()
                        running += 1
                        group.addTask {
                            let bundleID = String(format: "%@%03d", prefix, idx)
                            do {
                                try await manager.reloadExtension(withIdentifier: bundleID)
                                return (idx, nil)
                            } catch {
                                return (idx, error)
                            }
                        }
                    }

                    if let result = await group.next() {
                        running -= 1
                        await MainActor.run {
                            reloadProgress += 1
                            if let error = result.1 {
                                reloadErrors.append(String(format: "Ext%03d: %@", result.0, error.localizedDescription))
                            } else {
                                // 성공 시 앱에서 오프셋 증가
                                incrementOffset(for: result.0)
                            }
                        }
                    }
                }
            }

            await MainActor.run {
                reloadDuration = Date().timeIntervalSince(startTime)
                isReloading = false
                loadAccumulated()
                refreshStatuses()
            }
        }
    }

    private func refreshStatuses() {
        statusChecked = false
        statusCheckProgress = 0
        enabledCount = 0

        let manager = CXCallDirectoryManager.sharedInstance
        let prefix = Self.bundlePrefix

        Task {
            var count = 0
            // 10개씩 병렬 조회
            for batch in stride(from: 0, to: 100, by: 10) {
                let end = min(batch + 10, 100)
                await withTaskGroup(of: Bool.self) { group in
                    for i in batch..<end {
                        group.addTask {
                            let bundleID = String(format: "%@%03d", prefix, i)
                            do {
                                let status = try await manager.enabledStatusForExtension(withIdentifier: bundleID)
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
                await MainActor.run {
                    statusCheckProgress = end
                    enabledCount = count
                }
            }
            await MainActor.run {
                statusChecked = true
            }
        }
    }
}
