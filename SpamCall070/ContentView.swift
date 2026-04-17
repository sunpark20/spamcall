import SwiftUI
import CallKit

struct ContentView: View {

    @StateObject private var manager = ExtensionManager()
    @Environment(\.scenePhase) private var scenePhase
    @State private var reportSubmitted = false
    @State private var reportSubmitting = false
    @State private var statusCheckTimedOut = false

    private var allEnabled: Bool {
        manager.statusChecked && manager.enabledCount == ExtensionManager.extensionCount
    }

    private var reloadDone: Bool {
        manager.isLoaded
    }

    var body: some View {
        Form {
            // MARK: - Step 1
            Section {
                Button("1. [전화 차단 및 발신자 확인]에서 58개 항목 ON 하기") {
                    openCallBlockingSettings()
                }
                .font(.headline)
                .buttonStyle(.borderedProminent)
                .disabled(!manager.statusChecked || manager.isReloading)

                if manager.statusChecked {
                    HStack {
                        Text("\(manager.enabledCount) / \(ExtensionManager.extensionCount)개 활성화")
                            .monospacedDigit()
                        if allEnabled {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                } else if statusCheckTimedOut {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("시스템이 준비 중입니다.")
                            .foregroundStyle(.orange)
                        Text("앱을 닫고 30분 후 다시 열어주세요.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    HStack {
                        ProgressView()
                        Text("시스템 확인 중... (10분 정도 소요)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if manager.isReloading {
                    Text("로딩 중에는 설정의 '전화 차단 및 발신자 확인' 메뉴가 일시적으로 사라집니다. 로딩 완료 후 다시 나타납니다.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else if manager.statusChecked && !allEnabled {
                    VStack(alignment: .leading, spacing: 4) {
                        if #available(iOS 18, *) {
                            Text("설정 > 앱 > 전화 > 전화 차단 및 발신자 확인")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("설정 > 전화 > 전화 차단 및 발신자 확인")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("5개 ON, 5초 대기를 반복하며 모두 켜주세요. 버벅이면 창을 나갔다 들어오세요.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // MARK: - Step 2
            Section {
                Text("2. 1억건 로딩 시작하기")
                    .font(.headline)
                    .foregroundStyle(reloadDone ? Color.secondary : (allEnabled ? Color.primary : Color.secondary))

                if manager.isReloading {
                    HStack {
                        ProgressView()
                        Text("Block \(manager.reloadCurrent) 로딩 중...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(
                        value: Double(manager.reloadProgress),
                        total: Double(ExtensionManager.extensionCount)
                    )
                    Text("\(manager.reloadProgress) / \(ExtensionManager.extensionCount) 완료")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                } else if !manager.reloadErrors.isEmpty {
                    Text("\(manager.reloadErrors.count)개 실패")
                        .foregroundStyle(.red)

                    Button("실패 항목 재시도") {
                        manager.reloadFailed()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                } else {
                    Button("로딩 시작하기 (20분 소요)") {
                        manager.reloadAll()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!allEnabled || reloadDone)

                    Text("창을 유지해야 합니다. 중간에 전화 등으로 끊길 시 다시 눌러주세요.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // MARK: - Step 3 (완료 또는 실패)
            if reloadDone {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("3. 070-XXXX-XXXX 1억건이 차단되었습니다.")
                            .font(.headline)
                            .foregroundStyle(.green)
                        Text("영구 유지됩니다. 앱을 삭제하지 않는 한 계속 차단됩니다.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        let minutes = Int(manager.reloadDuration) / 60
                        let seconds = Int(manager.reloadDuration) % 60
                        Text("소요 시간: \(minutes)분 \(seconds)초")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }

                    DisclosureGroup("차단 구역 상세 (\(ExtensionManager.extensionCount)개)") {
                        ForEach(manager.allRanges) { range in
                            HStack(spacing: 8) {
                                Text(String(format: "%03d", range.index))
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Text(range.range)
                                    .font(.caption)
                                    .monospaced()
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            if manager.reloadDuration > 0 && !manager.reloadErrors.isEmpty {
                Section("실패 상세") {
                    ForEach(manager.reloadErrors, id: \.id) { error in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Block \(error.id.suffix(3))")
                                .font(.caption)
                                .fontWeight(.medium)
                            Text(error.message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if reportSubmitting {
                        HStack {
                            ProgressView()
                            Text("전송 중...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Button(reportSubmitted ? "신고 접수됨" : "에러 신고하기") {
                            reportSubmitting = true
                            Task {
                                let success = await manager.submitReport()
                                reportSubmitting = false
                                reportSubmitted = success
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .disabled(reportSubmitted)
                    }
                }
            }

            // MARK: - 초기화
            if manager.reloadProgress > 0 || manager.isLoaded || manager.reloadDuration > 0 {
            Section {
                Button("로딩 상태 초기화") {
                    manager.resetState()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)

                Text("로딩 진행 상태를 초기화하고 2단계부터 다시 시작합니다. 로딩이 중간에 실패하거나 다시 진행하고 싶을 때 사용하세요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            }
        }
        .onAppear {
            manager.refreshStatuses()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                manager.refreshStatuses()
            }
        }
        .task(id: manager.statusChecked) {
            if !manager.statusChecked {
                statusCheckTimedOut = false
                try? await Task.sleep(for: .seconds(120))
                if !manager.statusChecked {
                    statusCheckTimedOut = true
                }
            } else {
                statusCheckTimedOut = false
            }
        }
    }

    private func openCallBlockingSettings() {
        let candidates = [
            "App-prefs:com.apple.mobilephone&path=CALL_BLOCKING_AND_IDENTIFICATION",
            "App-prefs:com.apple.mobilephone",
            "prefs:root=Apps&path=com.apple.mobilephone",
            "App-prefs:Phone&path=CALL_BLOCKING_AND_IDENTIFICATION",
            "App-prefs:Phone",
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
}
