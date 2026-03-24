import SwiftUI
import CallKit

struct ExtensionStatusView: View {
    @StateObject private var viewModel = ExtensionStatusViewModel()

    var body: some View {
        List {
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView("상태 확인 중...")
                    Spacer()
                }
            }

            ForEach(viewModel.extensionStatuses) { status in
                Section(status.displayName) {
                    HStack {
                        Text("상태")
                        Spacer()
                        statusBadge(status.enabled)
                    }
                    HStack {
                        Text("등록된 번호")
                        Spacer()
                        Text("\(status.numberCount.formatted())개")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Bundle ID")
                        Spacer()
                        Text(status.bundleID)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !viewModel.isLoading && viewModel.extensionStatuses.isEmpty {
                Text("등록된 Extension이 없습니다")
                    .foregroundStyle(.secondary)
            }

            Section {
                Text("설정 > 전화 > 전화 차단 및 발신자 확인에서\nExtension을 활성화해야 합니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Extension 상태")
        .onAppear {
            viewModel.loadStatuses()
        }
        .refreshable {
            viewModel.loadStatuses()
        }
    }

    @ViewBuilder
    private func statusBadge(_ status: CXCallDirectoryManager.EnabledStatus) -> some View {
        switch status {
        case .enabled:
            Label("활성", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .disabled:
            Label("비활성", systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
        case .unknown:
            Label("알 수 없음", systemImage: "questionmark.circle")
                .foregroundStyle(.orange)
        @unknown default:
            Label("알 수 없음", systemImage: "questionmark.circle")
                .foregroundStyle(.orange)
        }
    }
}
