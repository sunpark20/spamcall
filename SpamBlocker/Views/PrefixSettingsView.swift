import SwiftUI
import SpamBlockerKit

struct PrefixSettingsView: View {
    @StateObject private var viewModel = PrefixSettingsViewModel()

    var body: some View {
        List {
            Section {
                HStack {
                    Text("선택된 번호대")
                    Spacer()
                    Text("\(viewModel.totalSelectedCount)개 (\(viewModel.totalSelectedNumbers.formatted())번호)")
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(viewModel.groups) { group in
                Section {
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { viewModel.expandedGroup == group.id },
                            set: { viewModel.expandedGroup = $0 ? group.id : nil }
                        )
                    ) {
                        prefixList(for: group)
                    } label: {
                        HStack {
                            Text(group.displayName)
                                .font(.headline)
                            Spacer()
                            Text("\(viewModel.selectedCountInGroup(group))/\(group.subPrefixCount)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button {
                        if viewModel.isGroupFullySelected(group) {
                            viewModel.deselectAllInGroup(group)
                        } else {
                            viewModel.selectAllInGroup(group)
                        }
                    } label: {
                        Text(viewModel.isGroupFullySelected(group) ? "전체 해제" : "전체 선택")
                            .font(.subheadline)
                    }
                }
            }
        }
        .navigationTitle("번호대 설정")
        .onAppear {
            viewModel.load()
        }
    }

    @ViewBuilder
    private func prefixList(for group: PrefixGroup) -> some View {
        // 성능을 위해 처음 100개만 표시, 나머지는 스크롤 시 로드
        let maxDisplay = min(group.subPrefixCount, 100)
        ForEach(0..<maxDisplay, id: \.self) { i in
            let entry = PrefixEntry(
                groupPrefix: group.domesticPrefix,
                subIndex: i,
                numberCount: group.numbersPerSubPrefix
            )
            Toggle(isOn: Binding(
                get: { viewModel.enabledPrefixes.contains(entry.id) },
                set: { _ in viewModel.togglePrefix(entry) }
            )) {
                HStack {
                    Text(entry.displayName)
                        .font(.system(.body, design: .monospaced))
                    Spacer()
                    Text("\(entry.numberCount.formatted())개")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }

        if group.subPrefixCount > 100 {
            Text("... 외 \(group.subPrefixCount - 100)개 번호대")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
