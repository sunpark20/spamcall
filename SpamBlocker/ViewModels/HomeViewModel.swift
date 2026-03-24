import Foundation
import SpamBlockerKit

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var totalBlockedCount: Int = 0
    @Published var enabledPrefixCount: Int = 0
    @Published var isGenerating: Bool = false
    @Published var generationProgress: String = ""

    private let prefixStore = PrefixStore.shared
    private let numberGenerator = NumberGenerator()
    private let binaryFileManager = BinaryFileManager()

    func loadStatus() {
        let enabled = prefixStore.loadEnabledPrefixes()
        enabledPrefixCount = enabled.count

        let fileURL = AppGroupManager.shared.defaultBinaryFilePath
        totalBlockedCount = binaryFileManager.numberCount(at: fileURL)
    }

    func applyChanges() {
        isGenerating = true
        generationProgress = "번호 생성 중..."

        Task.detached { [weak self] in
            guard let self else { return }
            let entries = self.prefixStore.loadEnabledEntries()
            let fileURL = AppGroupManager.shared.defaultBinaryFilePath

            do {
                let count = try self.numberGenerator.generateAndWriteToBinaryFile(
                    from: entries,
                    to: fileURL
                ) { written, total in
                    Task { @MainActor in
                        self.generationProgress = "생성 중: \(written.formatted()) / \(total.formatted())"
                    }
                }

                // Extension 설정 저장
                let config = ExtensionConfig.singleExtension(
                    prefixIDs: entries.map(\.id)
                )
                self.prefixStore.saveExtensionConfig(config)

                // Extension 리로드
                ExtensionManager.shared.reloadAllExtensions { success in
                    Task { @MainActor in
                        self.isGenerating = false
                        self.generationProgress = success
                            ? "완료: \(count.formatted())개 등록"
                            : "Extension 리로드 실패"
                        self.loadStatus()
                    }
                }
            } catch {
                await MainActor.run {
                    self.isGenerating = false
                    self.generationProgress = "오류: \(error.localizedDescription)"
                }
            }
        }
    }
}
