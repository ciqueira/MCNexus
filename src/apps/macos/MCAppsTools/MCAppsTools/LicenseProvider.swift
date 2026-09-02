import Foundation

// MARK: - App-level models (independent of Cryptlex)

struct LicenseInfo: Sendable {
    let edition: LicenseEditionType
}

enum LicenseEditionType: String, Sendable {
    case full = "Full"
    case demo = "Demo"
    case trial = "Trial"
    /// The SDK metadata can legitimately carry it, and without the case every
    /// beta license read back from a local receipt collapsed into `.full` —
    /// which is exactly how the Beta badge disappeared after the first sync.
    case beta = "Beta"

    init(fromMetadata value: String) {
        switch value.lowercased() {
        case "demo": self = .demo
        case "trial": self = .trial
        case "beta": self = .beta
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
    /// The SDK reached the server and learned this machine no longer holds a
    /// seat — the licence itself may be perfectly fine, someone just released
    /// this activation (nexkeyctl, the backOffice, an offline proof, another
    /// admin). Distinct from `notActivated`, which means "no local record and
    /// no way to tell why", and that distinction is the whole point: the two
    /// used to collapse into `notActivated`, which callers correctly read as
    /// "the call failed, skip this cycle" — so the one verdict that mattered
    /// was the one thrown away.
    case deactivatedRemotely
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

    /// Get the license key currently tracked by the SDK for a product.
    ///
    /// STRICTLY AN IDENTITY QUESTION — "which key is this SDK's local state
    /// about", never "is that state any good". A provider that folds the
    /// second question in here breaks every caller that uses this to decide
    /// whether to TRUST a status: the statuses worth learning about (revoked,
    /// suspended, seat released) would each make this return nil, and the
    /// verdict would be discarded for being about "some other key".
    func activatedKey(for product: AppProduct) async -> String?

    /// The SDK's own identifier for the local activation, if it has one.
    ///
    /// Recorded by the app right after a successful `activate()` so ownership
    /// survives a relaunch: NexKeyRuntime's ABI never hands a raw licence key
    /// back, so without a stable id the only in-memory answer dies with the
    /// process. Cryptlex has no equivalent concept and does not need one —
    /// `GetLicenseKey` already answers the identity question directly.
    func localActivationIdentifier(for product: AppProduct) async -> String?

    /// Re-establishes, after a relaunch, that this SDK's local state belongs
    /// to `key`. Returns true when it does.
    ///
    /// `activationId` is what makes this safe rather than a guess: the same
    /// machine can hold a seat for a DIFFERENT licence under the same product
    /// (deactivate A, activate B), and adopting on product alone would then
    /// report B's health as A's.
    func adoptLocalActivation(key: String, activationId: String?, for product: AppProduct) async -> Bool

    /// Get the machine fingerprint used for activation
    func machineFingerprint() -> String
}

extension LicenseProvider {
    /// Only for a provider with no per-activation identifier of its own —
    /// Cryptlex, whose `GetLicenseKey` answers the identity question directly.
    func localActivationIdentifier(for product: AppProduct) async -> String? { nil }

    /// DELIBERATELY PESSIMISTIC, and every provider with a local SDK must
    /// override it. `false` means "I cannot vouch that my local state is
    /// about this key", which makes the caller fall back to the backend —
    /// safe, but it also means a provider that forgets to override this
    /// silently stops contributing its verdict. `LexActivatorProvider`
    /// overrides it with the identity comparison it has always made.
    func adoptLocalActivation(key: String, activationId: String?, for product: AppProduct) async -> Bool { false }
}
