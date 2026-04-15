import SwiftUI
import CallKit

struct ContentView: View {

    @StateObject private var manager = ExtensionManager()
    @Environment(\.scenePhase) private var scenePhase

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
                Text("1. 설정에서 58개 ON 하기")
                    .font(.headline)
                    .foregroundStyle(allEnabled ? Color.secondary : Color.primary)

                if manager.statusChecked {
                    Button("전화 차단 및 발신자 확인 열기") {
                        openCallBlockingSettings()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(manager.isReloading)

                    HStack {
                        Text("\(manager.enabledCount) / \(ExtensionManager.extensionCount)개 활성화")
                            .monospacedDigit()
                        if allEnabled {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                } else {
                    HStack {
                        ProgressView()
                        Text("확인 중... 잠시 기다려주세요.")
                            .foregroundStyle(.secondary)
                    }
                }

                if manager.isReloading {
                    Text("로딩 중에는 설정의 '전화 차단 및 발신자 확인' 메뉴가 일시적으로 사라집니다. 로딩 완료 후 다시 나타납니다.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else if !allEnabled {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("설정 > 앱 > 전화 > 전화 차단 및 발신자 확인")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if #available(iOS 26, *) {
                            Text("iOS 26: 목록 가장 아래쪽에 있습니다.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("10개 ON 후 10초 대기를 반복해서 모두 켜주세요. 1억개 로딩이라 버벅이고 오류날 수 있으니, 창을 나갔다 들어오며 모두 ON 될 때까지 반복해주세요.")
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
                }
            }

            // MARK: - 초기화
            Section {
                Button("결과 초기화") {
                    manager.resetState()
                }
                .foregroundStyle(.red)
                .font(.caption)

                Text("문제가 생기면 앱 삭제 → 기기 재시작 → 앱 재설치 순서로 진행하세요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
