import Foundation
import SwiftData

/// Manages default data creation and restoration
final class DefaultDataManager {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Tags

    /// Creates default tags if none exist
    func createDefaultTagsIfNeeded() {
        let descriptor = FetchDescriptor<Tag>()
        let existingCount = (try? modelContext.fetchCount(descriptor)) ?? 0

        if existingCount == 0 {
            createDefaultTags()
        }
    }

    /// Creates all default tags
    func createDefaultTags() {
        for tagData in Tag.defaultTags {
            let tag = Tag(name: tagData.name, colorHex: tagData.colorHex)
            modelContext.insert(tag)
        }
        try? modelContext.save()
    }

    /// Restores default tags - adds any missing defaults without removing user-created ones
    func restoreDefaultTags() {
        let descriptor = FetchDescriptor<Tag>()
        let existingTags = (try? modelContext.fetch(descriptor)) ?? []
        let existingNames = Set(existingTags.map { $0.name.lowercased() })

        for tagData in Tag.defaultTags {
            if !existingNames.contains(tagData.name.lowercased()) {
                let tag = Tag(name: tagData.name, colorHex: tagData.colorHex)
                modelContext.insert(tag)
            }
        }
        try? modelContext.save()
    }

    /// Resets tags to defaults - removes all and recreates defaults
    func resetTagsToDefaults() {
        // Delete all existing tags
        let descriptor = FetchDescriptor<Tag>()
        if let existingTags = try? modelContext.fetch(descriptor) {
            for tag in existingTags {
                modelContext.delete(tag)
            }
        }

        // Create defaults
        createDefaultTags()
    }

    // MARK: - First Launch Setup

    /// Call this on first app launch to set up default data
    func setupDefaultData() {
        createDefaultTagsIfNeeded()
    }
}
