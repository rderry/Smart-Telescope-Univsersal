import Foundation
import SwiftData

struct SharedContainerBootstrap {
    let container: ModelContainer
    let storageWarning: String?
}

private struct PersistentStoreLocation {
    let applicationDirectory: URL
    let storeURL: URL
}

enum ModelContainerFactory {
    static var schema: Schema {
        Schema([
            DSOObject.self,
            TransientFeedItem.self,
            ObservingSite.self,
            EquipmentProfile.self,
            DefaultEquipmentConfiguration.self,
            SavedEquipmentConfiguration.self,
            SavedTargetList.self,
            SavedTargetListItem.self,
            CampaignPlan.self,
            NightPlan.self,
            PlannedTarget.self,
            CampaignLog.self,
            NightLog.self,
            ObservationEntry.self
        ])
    }

    static func makeSharedContainerBootstrap() -> SharedContainerBootstrap {
        do {
            let storeLocation = try makePersistentStoreLocation()
            let configuration = ModelConfiguration(url: storeLocation.storeURL)
            let container = try ModelContainer(for: schema, configurations: configuration)
            return SharedContainerBootstrap(container: container, storageWarning: nil)
        } catch {
            do {
                let recoveredContainer = try recoverPersistentContainer()
                return SharedContainerBootstrap(container: recoveredContainer, storageWarning: nil)
            } catch {
                let warning = AppIssueFormatter.storageWarning(for: error)

                do {
                    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
                    let container = try ModelContainer(for: schema, configurations: configuration)
                    return SharedContainerBootstrap(container: container, storageWarning: warning)
                } catch {
                    fatalError("Unable to create a shared or in-memory model container: \(error)")
                }
            }
        }
    }

    static func makeInMemoryContainer() -> ModelContainer {
        do {
            let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("Unable to create in-memory model container: \(error)")
        }
    }

    private static func makePersistentStoreLocation() throws -> PersistentStoreLocation {
        let fileManager = FileManager.default
        let baseDirectory = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let applicationDirectory = baseDirectory.appendingPathComponent("SmartScopeObservationPlanner", isDirectory: true)
        try fileManager.createDirectory(at: applicationDirectory, withIntermediateDirectories: true)

        let storeURL = applicationDirectory.appendingPathComponent("SmartScopeObservationPlanner.store")
        return PersistentStoreLocation(applicationDirectory: applicationDirectory, storeURL: storeURL)
    }

    private static func recoverPersistentContainer() throws -> ModelContainer {
        let fileManager = FileManager.default
        let storeLocation = try makePersistentStoreLocation()
        let recoveryDirectory = storeLocation.applicationDirectory.appendingPathComponent("RecoveredStores", isDirectory: true)
        try fileManager.createDirectory(at: recoveryDirectory, withIntermediateDirectories: true)

        let timestamp = ISO8601DateFormatter().string(from: .now).replacingOccurrences(of: ":", with: "-")

        for artifactURL in persistentStoreArtifacts(for: storeLocation.storeURL) where fileManager.fileExists(atPath: artifactURL.path) {
            let recoveredURL = recoveryDirectory.appendingPathComponent("\(timestamp)-\(artifactURL.lastPathComponent)")
            if fileManager.fileExists(atPath: recoveredURL.path) {
                try fileManager.removeItem(at: recoveredURL)
            }
            try fileManager.moveItem(at: artifactURL, to: recoveredURL)
        }

        let configuration = ModelConfiguration(url: storeLocation.storeURL)
        return try ModelContainer(for: schema, configurations: configuration)
    }

    private static func persistentStoreArtifacts(for storeURL: URL) -> [URL] {
        [
            storeURL,
            URL(fileURLWithPath: storeURL.path + "-shm"),
            URL(fileURLWithPath: storeURL.path + "-wal")
        ]
    }
}
