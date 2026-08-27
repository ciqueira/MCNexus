import Foundation

// MARK: - Shared

nonisolated struct AppBackendProductDTO: Codable, Sendable {
    let name: String
    let productID: String
    let purchaseURL: String?
    /// SDK product data, opaque to this app. Cryptlex-flavored for a
    /// `cryptlexLexActivatorV1` license and NexKeyRuntime-flavored for a
    /// `openkeyNexkeyruntimeV1` one — `licensing.runtime` on the enclosing
    /// response is the discriminator, never the shape of this field.
    let productData: String?
}

/// Mirrors the backend's `licensing` object (Fase 5, D41) — present on
/// `validate-installation`, `sync` and, per item, `sync-batch` responses.
/// Absent means an older backend or a legacy response shape; callers treat
/// that the same as `.cryptlexLexActivatorV1` (today's only behavior).
nonisolated struct LicensingDTO: Codable, Sendable {
    let runtime: String
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
    /// Additive (Fase 5). Absent on an older backend response — decodes to
    /// `nil`, which callers treat as the legacy Cryptlex runtime.
    let tenantId: String?
    let licensing: LicensingDTO?
    /// The license's download entitlements. Always exactly one for an
    /// OpenKey license — the backend enforces that
    /// (`normalizeSingleDownloadEntitlement`) — and it is what the SDK calls
    /// the `variant`. Needed here because `set_variant` decides which seat
    /// scope an activation binds to, so guessing it would bind the row to the
    /// wrong scope. Optional: an older backend omits it and the NexKey path
    /// falls back to the default entitlement.
    let entitlements: [String]?
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
    /// Additive (Fase 5) — see `ValidateInstallationResponseDTO`.
    let tenantId: String?
    let licensing: LicensingDTO?
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
    /// Additive (Fase 5, `PROPOSTA_SYNC_BATCH.md` backend round of 26/08) —
    /// per item, only on a successful (`ok: true`) result. See
    /// `ValidateInstallationResponseDTO`.
    let tenantId: String?
    let licensing: LicensingDTO?
    /// See `ValidateInstallationResponseDTO.entitlements`. Present per item
    /// on a successful result — a sync is how a NexKey-routed license
    /// refreshes its cached configuration between installs.
    let entitlements: [String]?
    /// "active" | "removed" | "unknown" — whether this machine still holds a
    /// seat. Absent for a legacy-routed item, and absent from any backend
    /// older than this field, both of which decode to `.unknown`.
    let activation: String?
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
    func toAppProduct() -> AppProduct {
        let resolvedURL = purchaseURL.flatMap { URL(string: $0) }
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

extension LicensingDTO {
    var asLicenseRuntime: LicenseRuntime {
        LicenseRuntime(wireValue: runtime)
    }
}

extension AppBackendMessageDTO {
    func toLicenseOperationMessage() -> LicenseOperationMessage {
        LicenseOperationMessage(code: code, message: message)
    }
}

// MARK: - Migrate Binding (Fase 5, D42 — step 4 of installation, before SDK activate)

nonisolated struct MigrateBindingRequestDTO: Codable, Sendable {
    /// macOS omits this: the session's own fingerprint is already the SDK's
    /// hardware id (`IOPlatformUUID`), so the backend derives the new
    /// binding from it directly. Windows must send it — the two identifiers
    /// there come from unrelated sources.
    let hardwareId: String?
}

nonisolated struct MigrateBindingResponseDTO: Codable, Sendable {
    let outcome: String
    let activationId: String?
}

// MARK: - App Latest (client update check)

nonisolated struct AppLatestResponseDTO: Codable, Sendable {
    let version: String
    let downloadURL: String
}
