import Foundation

struct LicenseOperationMessage: Sendable {
    let code: String
    let message: String
}

struct BackendFallbackNotice: Sendable {
    let userMessage: String
    let supportCode: String?
    let canRetry: Bool
    let preservesCachedData: Bool
}

enum LicenseOperationError: Error, Sendable {
    case backend(LicenseOperationMessage)
    case fallback(BackendFallbackNotice)
    case sdk(String)
    case local(String)

    var displayMessage: String {
        switch self {
        case .backend(let message):
            return message.message
        case .fallback(let notice):
            return notice.userMessage
        case .sdk(let message), .local(let message):
            return message
        }
    }

    var fallbackNotice: BackendFallbackNotice? {
        if case .fallback(let notice) = self {
            return notice
        }

        return nil
    }
}

struct LicenseBackendValidation: Sendable {
    let product: AppProduct
    let edition: LicenseEdition
    let skipLocalActivation: Bool
    let activationUsage: String
    let productData: String?
    let releases: [ReleaseInfo]
    let message: LicenseOperationMessage?
    /// Additive (Fase 5). `.cryptlexLexActivatorV1` when the backend omits
    /// `licensing` (older response, or a legacy tenant) — same as today's
    /// only behavior.
    let runtime: LicenseRuntime
    let tenantId: String?
}

/// Which SDK a license is routed to (Fase 5, D41 — the app never infers
/// this locally; the backend is the single source of truth per request).
/// `.unknown` keeps a string this build has never heard of instead of
/// silently misreporting it as one of the known cases.
///
/// `Codable` via `wireValue` — the same string both the backend's
/// `licensing.runtime` field and `PersistedLicense`'s on-disk storage use,
/// so a value round-trips identically whether it just came off the wire or
/// out of a cached file.
enum LicenseRuntime: Sendable, Equatable {
    case legacyBackendOnly
    case cryptlexLexActivatorV1
    case nexkeyRuntimeV1
    case unknown(String)

    init(wireValue: String) {
        switch wireValue {
        case "openkey_legacy_backend_only": self = .legacyBackendOnly
        case "cryptlex_lexactivator_v1": self = .cryptlexLexActivatorV1
        case "openkey_nexkeyruntime_v1": self = .nexkeyRuntimeV1
        default: self = .unknown(wireValue)
        }
    }

    var wireValue: String {
        switch self {
        case .legacyBackendOnly: return "openkey_legacy_backend_only"
        case .cryptlexLexActivatorV1: return "cryptlex_lexactivator_v1"
        case .nexkeyRuntimeV1: return "openkey_nexkeyruntime_v1"
        case .unknown(let raw): return raw
        }
    }
}

extension LicenseRuntime: Codable {
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self.init(wireValue: raw)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wireValue)
    }
}

struct LicenseBackendSyncRequest: Sendable {
    let key: String
    let product: AppProduct
}

struct LicenseBackendSync: Sendable {
    let key: String
    let product: AppProduct
    let status: LicenseBackendStatus
    /// THE BACKEND IS THE AUTHORITY ON THE EDITION, same as it is on seats.
    /// It used to be dropped on the floor here, leaving the local SDK as the
    /// only source — and the SDK has never been told about `beta`, so every
    /// sync silently rewrote a beta license as `full` and the badge vanished.
    /// `nil` means the response carried no edition (a failed batch item, or a
    /// backend older than the field): callers keep what they already had
    /// rather than inventing one.
    let edition: LicenseEdition?
    let activationUsage: String
    let releases: [ReleaseInfo]
    let skipLocalActivation: Bool?
    /// Additive (Fase 5) — see `LicenseBackendValidation.runtime`.
    let runtime: LicenseRuntime
    let tenantId: String?
    /// Whether THIS machine still holds a seat. Distinct from `status`, which
    /// describes the LICENCE: a licence stays `.active` forever while the
    /// activation on this machine is released, and until the backend started
    /// answering this the app had no way to tell the two apart.
    let activation: MachineActivationState
}

/// Mirrors the backend's `activation` field. `.unknown` is the honest answer
/// whenever the server could not derive this machine's SDK identity — today
/// that is Windows, where MCNexus reads the WMI SMBIOS UUID and the SDK reads
/// MachineGuid. It MUST be treated as "no information", never as "removed".
enum MachineActivationState: Sendable {
    case active
    case removed
    case unknown

    init(wireValue: String?) {
        switch wireValue?.lowercased() {
        case "active": self = .active
        case "removed": self = .removed
        default: self = .unknown
        }
    }
}

enum LicenseBackendStatus: Sendable {
    case active
    case expired
    case suspended
    case revoked
    case notFound
    case unknown
}

struct AppLatestInfo: Sendable {
    let version: String
    let downloadURL: URL
}

protocol LicenseBackendProvider: Sendable {
    func validateInstallationLicense(
        key: String,
        activateOnMachine: Bool
    ) async -> Result<LicenseBackendValidation, LicenseOperationError>

    func syncLicenses(
        _ requests: [LicenseBackendSyncRequest]
    ) async -> Result<[LicenseBackendSync], LicenseOperationError>

    func refreshLicenseStatus(
        key: String,
        product: AppProduct
    ) async -> LicenseBackendStatus

    func activationUsage(for key: String) async -> String

    func product(for product: AppProduct) async -> AppProduct

    /// Wakes up the backend before authenticated work runs. Default is a
    /// no-op; backends that hibernate (e.g. Render free tier) override this
    /// to ping a lightweight health endpoint so the first real request does
    /// not pay the cold-start cost.
    func warmUp() async

    /// Returns the latest published client release for this platform, or nil
    /// when the backend is unreachable / the payload is invalid. Best-effort:
    /// failures must be silent so the update banner never appears on transient
    /// errors.
    func fetchLatestApp() async -> AppLatestInfo?

    /// Fase 5 / D42 — unifies this machine's legacy activation identity with
    /// the one the SDK computes. Called once, at step 4 of installation
    /// (after download/install, immediately before the SDK's own activate),
    /// never earlier. Best-effort by contract: every outcome the backend can
    /// report is a non-error (D42 — "always 200"), and even a genuine
    /// transport failure must not block the SDK activation that follows —
    /// the worst case on failure is the pre-Fase-5 seat behavior for this one
    /// machine, not a broken install.
    func migrateBinding(key: String) async
}

extension LicenseBackendProvider {
    func warmUp() async {}
    func fetchLatestApp() async -> AppLatestInfo? { nil }
    func migrateBinding(key: String) async {}
}
