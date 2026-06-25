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
}

struct LicenseBackendSyncRequest: Sendable {
    let key: String
    let product: AppProduct
}

struct LicenseBackendSync: Sendable {
    let key: String
    let product: AppProduct
    let status: LicenseBackendStatus
    let activationUsage: String
    let releases: [ReleaseInfo]
    let skipLocalActivation: Bool?
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
}

extension LicenseBackendProvider {
    func warmUp() async {}
    func fetchLatestApp() async -> AppLatestInfo? { nil }
}
