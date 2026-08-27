import Foundation

/// Resolves which `LicenseProvider` a given license's local SDK calls go
/// through — Cryptlex or NexKeyRuntime — based on the `runtime` the backend
/// already returned for that license (Fase 5, D41). Deliberately stateless
/// per call, never "the coordinator's current runtime": coexistence means
/// two different products on the same machine can legitimately resolve to
/// two different runtimes at the same time (Grupo G1), so resolution has to
/// happen per license/per call, not once for the whole coordinator.
///
/// The two concrete providers are constructed once and held for the
/// router's lifetime — same discipline as the single `LexActivatorProvider`
/// the coordinator held before this existed.
struct LicenseRuntimeRouter: Sendable {
    private let cryptlexProvider: LicenseProvider
    private let nexKeyProvider: LicenseProvider

    init(
        cryptlexProvider: LicenseProvider = LexActivatorProvider(),
        nexKeyProvider: LicenseProvider = NexKeyRuntimeProvider()
    ) {
        self.cryptlexProvider = cryptlexProvider
        self.nexKeyProvider = nexKeyProvider
    }

    /// `nil` runtime is what every `PersistedLicense` written before this
    /// field existed decodes to — resolving it to Cryptlex is what makes
    /// that decode a no-op for every record already on disk.
    ///
    /// `.legacyBackendOnly` resolves to `nil`: no local SDK activation for
    /// that runtime, by design (D41) — the caller treats a `nil` provider
    /// exactly like today's `skipLocalActivation` path.
    func provider(for runtime: LicenseRuntime?) -> LicenseProvider? {
        switch runtime {
        case .none, .cryptlexLexActivatorV1, .unknown:
            return cryptlexProvider
        case .nexkeyRuntimeV1:
            return nexKeyProvider
        case .legacyBackendOnly:
            return nil
        }
    }
}
