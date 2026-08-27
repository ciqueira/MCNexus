import CryptoKit
import Foundation

/// The NexKeyRuntime configuration the BACKEND reported for one product,
/// cached on disk between launches.
///
/// WHY THIS EXISTS AT ALL. `NexKeyProductDataCatalog` compiles one entry per
/// tenant into the app, which means a tenant the binary has never heard of
/// cannot activate — `context(for:)` finds nothing and `activate()` returns
/// `sdkProductConfigurationMissing`. That is what a generation-2 tenant hits:
/// its `productID` is not in the catalog, and by §3.2 of Plano Tenant v2 its
/// ProductData is DERIVED from the tenant's signing keyset on every
/// validate-installation rather than stored as a config field, so there was
/// never a blob for anyone to paste into the catalog in the first place. The
/// backend already sends all three values the SDK needs; this store is what
/// keeps them across the launch that the SDK is asked about them.
///
/// DELIBERATELY NOT `ProductCredentialStore`. That store holds
/// Cryptlex-flavored blobs and its mere non-emptiness is load-bearing:
/// `LicenseWorkflowCoordinator.hasStoredProductData` reads it as "this
/// license has a local Cryptlex activation" when routing a deactivation.
/// Writing a NexKey-shaped blob there would make that check answer yes for a
/// license Cryptlex cannot deactivate — the exact stale-blob failure the
/// coordinator's own comment describes having already been bitten by. Two
/// runtimes, two stores, no shared key space.
struct NexKeyRuntimeConfigurationStore: Sendable {
    private static let storageDirectoryName = "NexKeyRuntimeConfigurations"
    private static let keyDerivationSalt = "MCAppsTools.NexKeyRuntimeConfigurationStore.v1"

    private let fileManager: FileManager
    private let machineFingerprintProvider: @Sendable () -> String

    init(
        fileManager: FileManager = .default,
        machineFingerprintProvider: @escaping @Sendable () -> String = { MachineFingerprint.generate() }
    ) {
        self.fileManager = fileManager
        self.machineFingerprintProvider = machineFingerprintProvider
    }

    func save(_ entry: NexKeyProductDataEntry, for productID: String) throws {
        let data = try JSONEncoder().encode(entry)
        let sealedBox = try AES.GCM.seal(data, using: encryptionKey(for: productID))
        guard let encryptedData = sealedBox.combined else {
            throw NexKeyRuntimeConfigurationStoreError.encryptionFailed
        }

        let directoryURL = try storageDirectoryURL()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try encryptedData.write(to: configurationURL(for: productID, in: directoryURL), options: .atomic)
    }

    /// Best-effort by contract — every failure returns `nil` rather than
    /// throwing, because the ONLY caller is the resolver behind
    /// `NexKeyRuntimeProvider`, whose fallback (the compiled-in catalog) is
    /// the right answer for every one of them.
    ///
    /// The interesting failure is a decrypt failure, and it is expected: the
    /// AES key is derived from the machine fingerprint, so restoring this
    /// app's Application Support onto different hardware leaves files that
    /// cannot open. Treating that as "not cached" is correct — the next
    /// validate-installation rewrites the entry with the blob the backend
    /// derives for that machine, and the derivation is per-request precisely
    /// so nothing has to be migrated.
    func load(for productID: String) -> NexKeyProductDataEntry? {
        guard let directoryURL = try? storageDirectoryURL() else { return nil }
        let fileURL = configurationURL(for: productID, in: directoryURL)
        guard fileManager.fileExists(atPath: fileURL.path),
              let encryptedData = try? Data(contentsOf: fileURL),
              let sealedBox = try? AES.GCM.SealedBox(combined: encryptedData),
              let decryptedData = try? AES.GCM.open(sealedBox, using: encryptionKey(for: productID)),
              let entry = try? JSONDecoder().decode(NexKeyProductDataEntry.self, from: decryptedData),
              !entry.productData.isEmpty, !entry.tenantId.isEmpty, !entry.variant.isEmpty else {
            return nil
        }
        return entry
    }

    func remove(for productID: String) throws {
        let fileURL = configurationURL(for: productID, in: try storageDirectoryURL())
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        try fileManager.removeItem(at: fileURL)
    }

    private func storageDirectoryURL() throws -> URL {
        try AppEnvironment.current
            .applicationSupportDirectoryURL(fileManager: fileManager)
            .appendingPathComponent(Self.storageDirectoryName, isDirectory: true)
    }

    private func configurationURL(for productID: String, in directoryURL: URL) -> URL {
        directoryURL.appendingPathComponent(fileName(for: productID), isDirectory: false)
    }

    private func fileName(for productID: String) -> String {
        let digest = SHA256.hash(data: Data(productID.utf8))
        return digest.map { String(format: "%02x", $0) }.joined() + ".bin"
    }

    private func encryptionKey(for productID: String) -> SymmetricKey {
        var material = Data()
        material.append(Data(Self.keyDerivationSalt.utf8))
        material.append(Data((Bundle.main.bundleIdentifier ?? "com.mcappstools.app").utf8))
        material.append(Data(machineFingerprintProvider().utf8))
        material.append(Data(productID.utf8))
        let digest = SHA256.hash(data: material)
        return SymmetricKey(data: digest)
    }
}

enum NexKeyRuntimeConfigurationStoreError: LocalizedError {
    case encryptionFailed

    var errorDescription: String? {
        switch self {
        case .encryptionFailed:
            return "NexKeyRuntime configuration encryption failed"
        }
    }
}

// MARK: - Resolution

protocol NexKeyProductDataResolving: Sendable {
    func entry(for productID: String) -> NexKeyProductDataEntry?
}

/// Backend first, compiled-in catalog second.
///
/// THAT ORDER, NOT THE REVERSE. The catalog is a snapshot taken at build
/// time; what the backend sends is the tenant's configuration RIGHT NOW,
/// keyring rotations included. Preferring the stale copy would mean a
/// rotation only took effect for whoever reinstalled the app, which is the
/// failure mode deriving the blob per request exists to prevent.
///
/// The catalog is not dead code behind it: it still answers on a machine
/// that has never completed a validate-installation for that product (an
/// offline first launch against `colorequalizer-oss`, the one tenant it
/// covers), and it is the floor the store's best-effort reads fall back to.
struct NexKeyProductDataResolver: NexKeyProductDataResolving {
    private let store: NexKeyRuntimeConfigurationStore

    init(store: NexKeyRuntimeConfigurationStore = NexKeyRuntimeConfigurationStore()) {
        self.store = store
    }

    func entry(for productID: String) -> NexKeyProductDataEntry? {
        store.load(for: productID) ?? NexKeyProductDataCatalog.entry(for: productID)
    }
}
