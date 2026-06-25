import CryptoKit
import Foundation

struct ProductCredentialStore: Sendable {
    private static let storageDirectoryName = "ProductCredentials"
    private static let keyDerivationSalt = "MCAppsTools.ProductCredentialStore.v1"

    private let fileManager: FileManager
    private let machineFingerprintProvider: @Sendable () -> String

    init(
        fileManager: FileManager = .default,
        machineFingerprintProvider: @escaping @Sendable () -> String = { MachineFingerprint.generate() }
    ) {
        self.fileManager = fileManager
        self.machineFingerprintProvider = machineFingerprintProvider
    }

    func saveProductData(_ productData: String, for productID: String) throws {
        let trimmedProductData = productData.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedProductData.isEmpty else {
            try removeProductData(for: productID)
            return
        }

        let data = Data(trimmedProductData.utf8)
        let sealedBox = try AES.GCM.seal(data, using: encryptionKey(for: productID))
        guard let encryptedData = sealedBox.combined else {
            throw ProductCredentialStoreError.encryptionFailed
        }

        let directoryURL = try storageDirectoryURL()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try encryptedData.write(to: credentialURL(for: productID, in: directoryURL), options: .atomic)
    }

    func loadProductData(for productID: String) throws -> String? {
        let fileURL = credentialURL(for: productID, in: try storageDirectoryURL())
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }

        let encryptedData = try Data(contentsOf: fileURL)
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        let decryptedData = try AES.GCM.open(sealedBox, using: encryptionKey(for: productID))

        guard let productData = String(data: decryptedData, encoding: .utf8), !productData.isEmpty else {
            throw ProductCredentialStoreError.invalidStoredData
        }
        return productData
    }

    func removeProductData(for productID: String) throws {
        let fileURL = credentialURL(for: productID, in: try storageDirectoryURL())
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        try fileManager.removeItem(at: fileURL)
    }

    private func storageDirectoryURL() throws -> URL {
        try AppEnvironment.current
            .applicationSupportDirectoryURL(fileManager: fileManager)
            .appendingPathComponent(Self.storageDirectoryName, isDirectory: true)
    }

    private func credentialURL(for productID: String, in directoryURL: URL) -> URL {
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

enum ProductCredentialStoreError: LocalizedError {
    case encryptionFailed
    case invalidStoredData

    var errorDescription: String? {
        switch self {
        case .encryptionFailed:
            return "Product data encryption failed"
        case .invalidStoredData:
            return "Stored product data is invalid"
        }
    }
}
