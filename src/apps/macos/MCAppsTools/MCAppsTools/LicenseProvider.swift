import Foundation

// MARK: - App-level models (independent of Cryptlex)

struct LicenseInfo: Sendable {
    let edition: LicenseEditionType
}

enum LicenseEditionType: String, Sendable {
    case full = "Full"
    case trial = "Trial"

    init(fromMetadata value: String) {
        switch value.lowercased() {
        case "trial", "demo": self = .trial
        default: self = .full
        }
    }
}

enum LicenseActivationStatus: Sendable {
    case activated
    case alreadyActivatedOnThisMachine
    case expired
    case suspended
    case revoked
    case noActivationsLeft
    case invalidKey
    case error(String)
}

enum LicenseDeactivationStatus: Sendable {
    case deactivated
    case notActivated
    case error(String)
}

enum LicenseValidationStatus: Sendable {
    case genuine
    case genuineGracePeriod
    case expired
    case suspended
    case revoked
    case notActivated
    case error(String)
}

// MARK: - Protocol

protocol LicenseProvider: Sendable {
    /// Activate a license key on this machine
    func activate(key: String, product: AppProduct) async -> LicenseActivationStatus

    /// Deactivate the current license on this machine
    func deactivate(product: AppProduct) async -> LicenseDeactivationStatus

    /// Check if the current license is still valid
    func validate(product: AppProduct) async -> LicenseValidationStatus

    /// Force an immediate sync of activation data from the persistent store
    func syncActivation(product: AppProduct) async -> LicenseValidationStatus

    /// Get license details (edition, activations, metadata)
    func getLicenseInfo(key: String, product: AppProduct) async throws -> LicenseInfo?

    /// Get the license key currently tracked by the SDK for a product
    func activatedKey(for product: AppProduct) async -> String?

    /// Get the machine fingerprint used for activation
    func machineFingerprint() -> String
}
