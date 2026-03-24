import Foundation
import SpamBlockerKit

@MainActor
final class PrefixSettingsViewModel: ObservableObject {
    @Published var groups: [PrefixGroup] = PrefixGroup.defaultGroups
    @Published var enabledPrefixes: Set<String> = []
    @Published var expandedGroup: String? = nil

    private let prefixStore = PrefixStore.shared

    var totalSelectedCount: Int {
        enabledPrefixes.count
    }

    var totalSelectedNumbers: Int {
        var count = 0
        for group in groups {
            for i in 0..<group.subPrefixCount {
                let entry = PrefixEntry(
                    groupPrefix: group.domesticPrefix,
                    subIndex: i,
                    numberCount: group.numbersPerSubPrefix
                )
                if enabledPrefixes.contains(entry.id) {
                    count += entry.numberCount
                }
            }
        }
        return count
    }

    func load() {
        enabledPrefixes = prefixStore.loadEnabledPrefixes()
    }

    func save() {
        prefixStore.saveEnabledPrefixes(enabledPrefixes)
    }

    func togglePrefix(_ entry: PrefixEntry) {
        if enabledPrefixes.contains(entry.id) {
            enabledPrefixes.remove(entry.id)
        } else {
            enabledPrefixes.insert(entry.id)
        }
        save()
    }

    func selectAllInGroup(_ group: PrefixGroup) {
        for i in 0..<group.subPrefixCount {
            let entry = PrefixEntry(
                groupPrefix: group.domesticPrefix,
                subIndex: i,
                numberCount: group.numbersPerSubPrefix
            )
            enabledPrefixes.insert(entry.id)
        }
        save()
    }

    func deselectAllInGroup(_ group: PrefixGroup) {
        for i in 0..<group.subPrefixCount {
            let id = "\(group.domesticPrefix)-\(i)"
            enabledPrefixes.remove(id)
        }
        save()
    }

    func isGroupFullySelected(_ group: PrefixGroup) -> Bool {
        for i in 0..<group.subPrefixCount {
            let id = "\(group.domesticPrefix)-\(i)"
            if !enabledPrefixes.contains(id) { return false }
        }
        return true
    }

    func selectedCountInGroup(_ group: PrefixGroup) -> Int {
        var count = 0
        for i in 0..<group.subPrefixCount {
            let id = "\(group.domesticPrefix)-\(i)"
            if enabledPrefixes.contains(id) { count += 1 }
        }
        return count
    }
}
