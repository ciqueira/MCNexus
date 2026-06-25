import CryptoKit
import Foundation

struct LicenseStore {
    private static var licensesStorageKey: String { AppEnvironment.current.licensesStorageKey }
    private static let storageDirectoryComponents = ["State", "Records"]
    private static let keyDerivationSalt = "MCAppsTools.LicenseStore.v1"

    private let defaults: UserDefaults
    private let fileManager: FileManager
    private let machineFingerprintProvider: () -> String

    init(
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default,
        machineFingerprintProvider: @escaping () -> String = { MachineFingerprint.generate() }
    ) {
        self.defaults = defaults
        self.fileManager = fileManager
        self.machineFingerprintProvider = machineFingerprintProvider
    }

    func saveLicenses(_ licenses: [PersistedLicense]) throws {
        let existingIDs = Set(loadStoredLicenseIDs())
        let currentIDs = Set(licenses.map(\.id))

        for license in licenses {
            if let key = license.lastKnownLicenseKey, !key.isEmpty {
                try storeLicenseKey(key, for: license.id)
            } else {
                try removeLicenseKey(for: license.id)
            }
        }

        for removedID in existingIDs.subtracting(currentIDs) {
            try removeLicenseKey(for: removedID)
        }

        let sanitized = licenses.map { license in
            PersistedLicense(
                id: license.id,
                product: license.product,
                pluginName: license.pluginName,
                edition: license.edition,
                installedVersion: license.installedVersion,
                availableVersion: license.availableVersion,
                lastKnownLicenseKey: nil,
                activationDate: license.activationDate,
                pluginUpdateDate: license.pluginUpdateDate,
                activationUsage: license.activationUsage,
                deactivationDate: license.deactivationDate,
                previousVersions: license.previousVersions,
                lifecycleState: license.lifecycleState,
                isRevoked: license.isRevoked,
                installedBundleNames: license.installedBundleNames
            )
        }

        let data = try JSONEncoder().encode(sanitized)
        defaults.set(data, forKey: Self.licensesStorageKey)
    }

    func loadLicenses() throws -> [PersistedLicense] {
        guard let data = defaults.data(forKey: Self.licensesStorageKey) else {
            return []
        }

        let persisted = try JSONDecoder().decode([PersistedLicense].self, from: data)
        var migratedLicenses: [PersistedLicense] = []
        var didMigratePlaintextKeys = false

        for license in persisted {
            var migrated = license

            if let legacyKey = license.lastKnownLicenseKey, !legacyKey.isEmpty {
                try storeLicenseKey(legacyKey, for: license.id)
                migrated.lastKnownLicenseKey = legacyKey
                didMigratePlaintextKeys = true
            } else {
                migrated.lastKnownLicenseKey = try loadLicenseKey(for: license.id)
            }

            migratedLicenses.append(migrated)
        }

        if didMigratePlaintextKeys {
            try saveLicenses(migratedLicenses)
        }

        return migratedLicenses
    }

    private func loadStoredLicenseIDs() -> [UUID] {
        guard let data = defaults.data(forKey: Self.licensesStorageKey),
              let persisted = try? JSONDecoder().decode([PersistedLicense].self, from: data) else {
            return []
        }

        return persisted.map(\.id)
    }

    private func storeLicenseKey(_ key: String, for id: UUID) throws {
        let data = Data(key.utf8)
        let sealedBox = try AES.GCM.seal(data, using: encryptionKey(for: id))
        guard let encryptedData = sealedBox.combined else {
            throw LicenseStoreError.encryptionFailed
        }

        let directoryURL = try storageDirectoryURL()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try encryptedData.write(to: credentialURL(for: id, in: directoryURL), options: .atomic)
    }

    private func loadLicenseKey(for id: UUID) throws -> String? {
        let fileURL = credentialURL(for: id, in: try storageDirectoryURL())
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }

        let encryptedData = try Data(contentsOf: fileURL)
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        let decryptedData = try AES.GCM.open(sealedBox, using: encryptionKey(for: id))

        guard let value = String(data: decryptedData, encoding: .utf8), !value.isEmpty else {
            throw LicenseStoreError.invalidStoredData
        }
        return value
    }

    private func removeLicenseKey(for id: UUID) throws {
        let fileURL = credentialURL(for: id, in: try storageDirectoryURL())
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        try fileManager.removeItem(at: fileURL)
    }

    /// Reports whether the encrypted credential file backing this license is
    /// still present on disk. Reconciliation uses this so a manually-deleted
    /// `.dat` is detected before the user clicks Deactivate and trips the
    /// SDK's `sdkProductConfigurationMissing` error.
    func licenseKeyExists(for id: UUID) -> Bool {
        do {
            let fileURL = credentialURL(for: id, in: try storageDirectoryURL())
            return fileManager.fileExists(atPath: fileURL.path)
        } catch {
            return false
        }
    }

    private func storageDirectoryURL() throws -> URL {
        var url = try AppEnvironment.current.applicationSupportDirectoryURL(fileManager: fileManager)

        for component in Self.storageDirectoryComponents {
            url.appendPathComponent(component, isDirectory: true)
        }
        return url
    }

    private func credentialURL(for id: UUID, in directoryURL: URL) -> URL {
        directoryURL.appendingPathComponent(fileName(for: id), isDirectory: false)
    }

    private func fileName(for id: UUID) -> String {
        let digest = SHA256.hash(data: Data(id.uuidString.utf8))
        return digest.map { String(format: "%02x", $0) }.joined() + ".dat"
    }

    private func encryptionKey(for id: UUID) -> SymmetricKey {
        var material = Data()
        material.append(Data(Self.keyDerivationSalt.utf8))
        material.append(Data((Bundle.main.bundleIdentifier ?? "com.mcappstools.app").utf8))
        material.append(Data(machineFingerprintProvider().utf8))
        material.append(Data(id.uuidString.utf8))
        let digest = SHA256.hash(data: material)
        return SymmetricKey(data: digest)
    }
}

enum LicenseStoreError: LocalizedError {
    case encryptionFailed
    case invalidStoredData

    var errorDescription: String? {
        switch self {
        case .encryptionFailed:
            return "License credential encryption failed"
        case .invalidStoredData:
            return "Stored license credential is invalid"
        }
    }
}
