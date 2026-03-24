import Foundation
import CallKit
import SpamBlockerKit

@MainActor
final class ExtensionStatusViewModel: ObservableObject {
    @Published var extensionStatuses: [ExtensionStatus] = []
    @Published var isLoading: Bool = false

    struct ExtensionStatus: Identifiable {
        let id: String
        let bundleID: String
        let displayName: String
        var enabled: CXCallDirectoryManager.EnabledStatus = .unknown
        var numberCount: Int = 0
    }

    func loadStatuses() {
        isLoading = true
        let binaryManager = BinaryFileManager()

        extensionStatuses = SpamBlockerConstants.extensionBundleIDs.enumerated().map { index, bundleID in
            let fileURL = AppGroupManager.shared.binaryFilePath(for: index)
            let count = binaryManager.numberCount(at: fileURL)
            return ExtensionStatus(
                id: bundleID,
                bundleID: bundleID,
                displayName: "Extension \(index + 1)",
                numberCount: count
            )
        }

        for (index, status) in extensionStatuses.enumerated() {
            ExtensionManager.shared.getEnabledStatus(for: status.bundleID) { [weak self] enabledStatus in
                Task { @MainActor in
                    guard let self, index < self.extensionStatuses.count else { return }
                    self.extensionStatuses[index].enabled = enabledStatus
                    if index == self.extensionStatuses.count - 1 {
                        self.isLoading = false
                    }
                }
            }
        }
    }
}
