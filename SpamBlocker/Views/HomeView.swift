import SwiftUI
import SpamBlockerKit

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()

    var body: some View {
        NavigationStack {
            List {
                Section("차단 현황") {
                    HStack {
                        Label("차단 번호", systemImage: "phone.down.fill")
                        Spacer()
                        Text("\(viewModel.totalBlockedCount.formatted())개")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Label("활성 번호대", systemImage: "number")
                        Spacer()
                        Text("\(viewModel.enabledPrefixCount)개")
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    NavigationLink {
                        PrefixSettingsView()
                    } label: {
                        Label("번호대 설정", systemImage: "slider.horizontal.3")
                    }

                    NavigationLink {
                        ExtensionStatusView()
                    } label: {
                        Label("Extension 상태", systemImage: "puzzlepiece.extension")
                    }
                }

                Section {
                    Button {
                        viewModel.applyChanges()
                    } label: {
                        HStack {
                            Label("차단 적용하기", systemImage: "arrow.clockwise")
                            Spacer()
                            if viewModel.isGenerating {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(viewModel.isGenerating)

                    if !viewModel.generationProgress.isEmpty {
                        Text(viewModel.generationProgress)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("SpamBlocker")
            .onAppear {
                viewModel.loadStatus()
            }
        }
    }
}
