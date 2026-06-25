import Foundation

// MARK: - Shared

nonisolated struct AppBackendProductDTO: Codable, Sendable {
    let name: String
    let productID: String
    let purchaseURL: String?
    /// Cryptlex SDK productData. Returned by the backend nested inside `product`
    /// in validate-installation/sync responses.
    let productData: String?
}

nonisolated struct AppBackendReleaseDTO: Codable, Sendable {
    let id: String
    let name: String
    let version: String
    let platform: String
    let channel: String?
    let updatedAt: String?
    let publishedAt: String?
    let totalFiles: Int?
}

nonisolated struct AppBackendMessageDTO: Codable, Sendable {
    let code: String
    let message: String
}

nonisolated struct AppBackendErrorDTO: Codable, Sendable {
    let code: String
    let message: String
}

// MARK: - Health

nonisolated struct HealthResponseDTO: Codable, Sendable {
    let status: String
    let version: String?
}

// MARK: - Validate Installation

nonisolated struct ValidateInstallationRequestDTO: Codable, Sendable {
    let key: String
    let machineFingerprint: String
    let activateOnMachine: Bool
}

nonisolated struct ValidateInstallationResponseDTO: Codable, Sendable {
    let product: AppBackendProductDTO
    let edition: String
    let skipLocalActivation: Bool?
    let activationUsage: String
    let releases: [AppBackendReleaseDTO]
    let sessionToken: String?
    let expiresIn: Int?
    let message: AppBackendMessageDTO?
}

// MARK: - Sync (single license per call, identified by Bearer JWT sessionToken)

nonisolated struct SyncLicenseRequestDTO: Codable, Sendable {
    let machineFingerprint: String
}

nonisolated struct SyncLicenseResponseDTO: Codable, Sendable {
    let product: AppBackendProductDTO
    let edition: String?
    let status: String
    let activationUsage: String
    let releases: [AppBackendReleaseDTO]
    let sessionToken: String?
    let expiresIn: Int?
}

// MARK: - Sync Batch

nonisolated struct SyncBatchRequestDTO: Codable, Sendable {
    let machineFingerprint: String
    let items: [SyncBatchItemDTO]
}

nonisolated struct SyncBatchItemDTO: Codable, Sendable {
    let key: String
    let sessionToken: String?
}

nonisolated struct SyncBatchResponseDTO: Codable, Sendable {
    let results: [SyncBatchResultDTO]
}

nonisolated struct SyncBatchResultDTO: Codable, Sendable {
    let key: String
    let ok: Bool
    let status: String?
    let edition: String?
    let skipLocalActivation: Bool?
    let activationUsage: String?
    let product: AppBackendProductDTO?
    let releases: [AppBackendReleaseDTO]?
    let sessionToken: String?
    let expiresIn: Int?
    let message: AppBackendMessageDTO?
    let error: AppBackendErrorDTO?
}

// MARK: - Resolve Download

nonisolated struct ResolveDownloadRequestDTO: Codable, Sendable {
    let platform: String
    let machineFingerprint: String
}

nonisolated struct ResolveDownloadResponseDTO: Codable, Sendable {
    let name: String
    let url: String
    let expiresAt: String?
    let fileSize: Int?
}

// MARK: - DTO → App model mapping

extension AppBackendProductDTO {
    func toAppProduct(fallbackPurchaseURL: URL?) -> AppProduct {
        let resolvedURL: URL?
        if let purchaseURL, let parsed = URL(string: purchaseURL) {
            resolvedURL = parsed
        } else {
            resolvedURL = fallbackPurchaseURL
        }
        return AppProduct(name: name, productID: productID, purchaseURL: resolvedURL)
    }
}

extension AppBackendReleaseDTO {
    func toReleaseInfo() -> ReleaseInfo {
        ReleaseInfo(
            id: id,
            name: name,
            version: version,
            channel: channel ?? "stable",
            platform: platform,
            updatedAt: updatedAt,
            publishedAt: publishedAt,
            totalFiles: totalFiles ?? 0
        )
    }
}

extension String {
    var asLicenseBackendStatus: LicenseBackendStatus {
        switch lowercased() {
        case "active": return .active
        case "expired": return .expired
        case "suspended": return .suspended
        case "revoked": return .revoked
        case "notfound", "not_found": return .notFound
        default: return .unknown
        }
    }

    var asLicenseEdition: LicenseEdition {
        switch lowercased() {
        case "trial", "demo": return .trial
        case "beta": return .beta
        default: return .full
        }
    }
}

extension AppBackendMessageDTO {
    func toLicenseOperationMessage() -> LicenseOperationMessage {
        LicenseOperationMessage(code: code, message: message)
    }
}

// MARK: - App Latest (client update check)

nonisolated struct AppLatestResponseDTO: Codable, Sendable {
    let version: String
    let downloadURL: String
}
