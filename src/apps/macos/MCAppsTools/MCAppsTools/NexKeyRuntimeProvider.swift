import Foundation

/// `LicenseProvider` over the NexKeyRuntime C ABI (`nexkeyruntime.h`), the
/// SDK-routed sibling of `LexActivatorProvider`. Conforms to the same
/// runtime-agnostic protocol so `LicenseRuntimeRouter` (Fase 5, Round 3) can
/// hand either provider to `LicenseWorkflowCoordinator` without it knowing
/// which SDK is underneath.
///
/// Unlike Cryptlex's global mutable state (reinitialized before every call,
/// see `LexActivatorProvider.initializeSDK`), NexKeyRuntime hands out an
/// explicit `NexKeyRuntimeLicenseHandle*` per configuration — created once
/// per product and reused, mirroring `mc::License` in the ColorEqualizer
/// plugin's `MCLicense.h`, the reference this class's lifecycle is ported
/// from.
final class NexKeyRuntimeProvider: LicenseProvider, @unchecked Sendable {
    private let sdkQueue = DispatchQueue(label: "com.mcappstools.nexkeyruntime")
    /// Where `set_product_data`/`set_tenant_id`/`set_variant` get their
    /// values. Backend-first, catalog-fallback — see
    /// `NexKeyProductDataResolver`. Injected so tests can supply an entry
    /// without touching Application Support.
    private let productDataResolver: NexKeyProductDataResolving
    /// Confined to `sdkQueue` — every read and write happens inside a block
    /// dispatched to it, so no separate lock is needed for the dictionary
    /// itself (the C handle it stores is not thread-confined the same way;
    /// see the poller-callback note below).
    private var handles: [String: NexKeyHandleContext] = [:]

    init(productDataResolver: NexKeyProductDataResolving = NexKeyProductDataResolver()) {
        self.productDataResolver = productDataResolver
    }

    deinit {
        for context in handles.values {
            nexkeyruntime_license_destroy(context.handle)
        }
    }

    // MARK: - Per-product handle

    /// Holds one product's handle plus the state the poller callback (which
    /// runs on the SDK's own background thread, never `sdkQueue`) needs to
    /// report back safely.
    private final class NexKeyHandleContext {
        let handle: OpaquePointer
        /// The configuration this handle was built from. Kept so
        /// `context(for:)` can tell a still-current handle from one whose
        /// tenant rotated its signing key underneath it.
        let entry: NexKeyProductDataEntry
        let syncSignal = SyncPollSignal()

        /// The key most recently handed to `activate()` on this handle,
        /// cleared on `deactivate()`. NexKeyRuntime's ABI never hands a raw
        /// key back (unlike Cryptlex's `GetLicenseKey`), so this in-memory
        /// cache is the only way `activatedKey(for:)`/`getLicenseInfo` can
        /// answer. Deliberate, flagged gap: it does not survive an app
        /// relaunch — a genuinely active license then reads as "unknown key"
        /// for one refresh cycle, until `refreshLicenses`'s fuller path
        /// (which does not depend on this cache) re-establishes state.
        var lastActivatedKey: String?

        init(handle: OpaquePointer, entry: NexKeyProductDataEntry) {
            self.handle = handle
            self.entry = entry
        }
    }

    /// Thread-safe counter the poller callback bumps. `NSLock` rather than
    /// `sdkQueue`, because the callback fires on the SDK's own background
    /// thread — the ABI documents it must not block and must not call back
    /// into the handle, so it cannot itself hop onto `sdkQueue`.
    private final class SyncPollSignal {
        private let lock = NSLock()
        private var count = 0

        func bump() {
            lock.lock()
            count += 1
            lock.unlock()
        }

        func snapshot() -> Int {
            lock.lock()
            defer { lock.unlock() }
            return count
        }
    }

    private func unsupportedProductError(for product: AppProduct) -> LicenseActivationStatus {
        .error(AppMessages.text(.sdkProductConfigurationMissing, product.displayName))
    }

    /// Creates (on first use) and configures the handle for this product.
    /// Must run on `sdkQueue`. Order mirrors `mc::License::start()` exactly:
    /// create -> set_callback -> set_product_data -> set_tenant_id ->
    /// set_variant -> set_metadata("product", ...) (D40 — before any
    /// `activate()`).
    private func context(for product: AppProduct) -> NexKeyHandleContext? {
        guard let entry = productDataResolver.entry(for: product.productID) else {
            return nil
        }
        if let existing = handles[product.productID] {
            if existing.entry == entry {
                return existing
            }
            // The configuration moved under a live handle. Only a key
            // rotation does this in practice — a generation-2 tenant's blob
            // is derived from its keyset with the ACTIVE KEY's own createdAt
            // as `issuedAt` (Plano Tenant v2, §3.2), deliberately so that an
            // unchanged keyset always derives byte-identical bytes and this
            // comparison stays quiet.
            //
            // Rebuilt, not reconfigured: `set_product_data` is only honoured
            // before the handle's first `activate()`, so a handle that has
            // already been used cannot be pointed at a new keyring. The cost
            // is `lastActivatedKey`, which does not survive the rebuild —
            // the same one-refresh-cycle gap an app relaunch already has, and
            // documented on that field. Nothing on disk is touched: the
            // receipt and the seat outlive the handle, and `load_local`
            // picks them back up.
            nexkeyruntime_license_destroy(existing.handle)
            handles[product.productID] = nil
        }
        guard let handle = nexkeyruntime_license_create() else {
            return nil
        }
        let context = NexKeyHandleContext(handle: handle, entry: entry)

        // Capture-less closure: the only way a Swift closure converts to the
        // C function pointer `NexKeyRuntimeLicenseCallback` expects. Runs on
        // the poller thread — records and returns, never calls back into the
        // handle, per the ABI's own contract.
        nexkeyruntime_license_set_callback(handle, { _, userData in
            guard let userData else { return }
            Unmanaged<NexKeyHandleContext>.fromOpaque(userData)
                .takeUnretainedValue()
                .syncSignal.bump()
        }, Unmanaged.passUnretained(context).toOpaque())

        guard nexkeyruntime_license_set_product_data(handle, entry.productData) == NEXKEYRUNTIME_OK else {
            nexkeyruntime_license_destroy(handle)
            return nil
        }
        _ = nexkeyruntime_license_set_tenant_id(handle, entry.tenantId)
        _ = nexkeyruntime_license_set_variant(handle, entry.variant)
        // "What the program calls itself" (activation_clients schema) — the
        // INTEGRATOR's name, not the product's. `nexkeyctl` identifies as
        // "nexkeyctl"; LexActivatorProvider identifies as "MCAppsTools" via
        // SetActivationMetadata("app", ...). This is that same self-ID for
        // MCNexus, never the per-product UUID.
        _ = nexkeyruntime_license_set_metadata(handle, "product", "mcnexus")

        // THE OTHER HALF OF THAT IDENTITY, and leaving it out froze the
        // version the backoffice shows. "appVersion" is the only other key
        // the SDK understands (LicenseHandle.cpp — everything else is
        // accepted and ignored), and LicenseClient omits the field from the
        // request body when it is empty. So an MCNexus that never set it
        // reported `appVersion: null` on every activate AND every poller
        // sync, and recordActivationClient's
        // `COALESCE(EXCLUDED.app_version, ...)` — right, since a client that
        // goes quiet must not erase what we knew — then preserved whatever
        // number was recorded once, forever. The row read "mcnexus · sdk
        // 0.5.0" with a stale build number behind it that no update could
        // move.
        //
        // The same string `X-App-Version` carries, deliberately: one build
        // is one version, and the appClient audit log and this row
        // disagreeing about which would be a puzzle with no upside.
        //
        // NOT SENT WHEN THE VERSION IS UNKNOWN. `appVersion` falls back to
        // the literal "unknown" when the bundled VERSION resource cannot be
        // read; that is a fine value for a header nobody stores, but here it
        // is non-null and would overwrite a good number through the COALESCE
        // above. Staying silent is what that COALESCE is for.
        let appVersion = AppBackendConfiguration.appVersion
        if appVersion != "unknown", !appVersion.isEmpty {
            _ = nexkeyruntime_license_set_metadata(handle, "appVersion", appVersion)
        }

        handles[product.productID] = context
        return context
    }

    // MARK: - Activate

    func activate(key: String, product: AppProduct) async -> LicenseActivationStatus {
        guard productDataResolver.entry(for: product.productID) != nil else {
            return unsupportedProductError(for: product)
        }
        return await withCheckedContinuation { continuation in
            sdkQueue.async { [self] in
                continuation.resume(returning: activateSync(key: key, product: product))
            }
        }
    }

    private func activateSync(key: String, product: AppProduct) -> LicenseActivationStatus {
        guard let context = context(for: product) else {
            return unsupportedProductError(for: product)
        }

        guard nexkeyruntime_license_set_license_key(context.handle, key) == NEXKEYRUNTIME_OK else {
            return .error(AppMessages.text(.sdkSetLicenseKeyFailed, key))
        }

        let result = nexkeyruntime_license_activate(context.handle)
        switch result {
        case NEXKEYRUNTIME_OK:
            context.lastActivatedKey = key
            return .activated
        case NEXKEYRUNTIME_E_PRODUCT_ACTIVATED:
            context.lastActivatedKey = key
            return .alreadyActivatedOnThisMachine
        case NEXKEYRUNTIME_E_ACTIVATION_LIMIT:
            return .noActivationsLeft
        case NEXKEYRUNTIME_E_LICENSE_KEY:
            return .invalidKey
        case NEXKEYRUNTIME_E_LICENSE_EXPIRED:
            return .expired
        case NEXKEYRUNTIME_E_LICENSE_SUSPENDED:
            return .suspended
        case NEXKEYRUNTIME_E_LICENSE_REVOKED:
            return .revoked
        default:
            return .error(AppMessages.text(.sdkActivationFailed, resultName(result)))
        }
    }

    // MARK: - Deactivate

    func deactivate(product: AppProduct) async -> LicenseDeactivationStatus {
        guard productDataResolver.entry(for: product.productID) != nil else {
            return .error(AppMessages.text(.sdkProductConfigurationMissing, product.displayName))
        }
        return await withCheckedContinuation { continuation in
            sdkQueue.async { [self] in
                continuation.resume(returning: deactivateSync(product: product))
            }
        }
    }

    private func deactivateSync(product: AppProduct) -> LicenseDeactivationStatus {
        guard let context = context(for: product) else {
            return .error(AppMessages.text(.sdkProductConfigurationMissing, product.displayName))
        }

        let result = nexkeyruntime_license_deactivate(context.handle)
        switch result {
        case NEXKEYRUNTIME_OK:
            context.lastActivatedKey = nil
            return .deactivated
        case NEXKEYRUNTIME_E_NO_RECEIPT, NEXKEYRUNTIME_E_ACTIVATION_NOT_FOUND:
            context.lastActivatedKey = nil
            return .notActivated
        default:
            return .error(AppMessages.text(.sdkDeactivationFailed, resultName(result)))
        }
    }

    // MARK: - Validate (Bloco A — local, no network)

    func validate(product: AppProduct) async -> LicenseValidationStatus {
        guard productDataResolver.entry(for: product.productID) != nil else {
            return .notActivated
        }
        return await withCheckedContinuation { continuation in
            sdkQueue.async { [self] in
                continuation.resume(returning: validateSync(product: product))
            }
        }
    }

    private func validateSync(product: AppProduct) -> LicenseValidationStatus {
        guard let context = context(for: product) else {
            return .notActivated
        }
        _ = nexkeyruntime_license_load_local(context.handle)

        var snapshot = NexKeyRuntimeLicenseSnapshot()
        snapshot.struct_size = MemoryLayout<NexKeyRuntimeLicenseSnapshot>.size
        guard nexkeyruntime_license_get_snapshot(context.handle, &snapshot) == NEXKEYRUNTIME_OK else {
            return .notActivated
        }
        return validationStatus(for: snapshot.status)
    }

    // MARK: - Sync Activation (Bloco C — forces a network round trip)

    func syncActivation(product: AppProduct) async -> LicenseValidationStatus {
        guard productDataResolver.entry(for: product.productID) != nil else {
            return .notActivated
        }
        return await withCheckedContinuation { continuation in
            sdkQueue.async { [self] in
                continuation.resume(returning: syncActivationSync(product: product))
            }
        }
    }

    private func syncActivationSync(product: AppProduct) -> LicenseValidationStatus {
        guard let context = context(for: product) else {
            return .notActivated
        }

        // `request_sync` is only synchronous when no poller thread exists.
        // Once one is running — which it is, on any interactive host with a
        // stored key — the call hands the work to that thread and returns
        // immediately, so reading the snapshot right after would show the
        // state from BEFORE the sync. Ported from `mc::License::syncNow()`
        // (`MCLicense.h`): wait for the callback to fire, bounded at ~4s.
        let before = context.syncSignal.snapshot()
        let requestResult = nexkeyruntime_license_request_sync(context.handle, 1)

        // THE SNAPSHOT IS READ EVEN WHEN THE CALL "FAILED", and that is the
        // point. `request_sync` maps the server's verdict onto its return
        // code — `E_ACTIVATION_NOT_FOUND` for a released seat,
        // `E_LICENSE_REVOKED` for a revoked licence — and it does so AFTER
        // `applyOutcomeLocked` has already written the right answer into the
        // handle. Returning early on non-OK therefore threw away the freshly
        // fetched verdict and reported a generic error instead, which callers
        // read as "network trouble, try later". Forever.
        if requestResult == NEXKEYRUNTIME_OK {
            for _ in 0..<80 {
                if context.syncSignal.snapshot() != before { break }
                Thread.sleep(forTimeInterval: 0.05)
            }
        }

        var snapshot = NexKeyRuntimeLicenseSnapshot()
        snapshot.struct_size = MemoryLayout<NexKeyRuntimeLicenseSnapshot>.size
        guard nexkeyruntime_license_get_snapshot(context.handle, &snapshot) == NEXKEYRUNTIME_OK else {
            return syncFailureStatus(requestResult)
        }

        let status = validationStatus(for: snapshot.status)
        if case .notActivated = status {
            // No local state to report on. Whether that is a VERDICT or just
            // a broken call is decided by why the sync could not run — see
            // syncFailureStatus.
            return syncFailureStatus(requestResult)
        }
        return status
    }

    /// Separates "there is genuinely no activation on this machine" from "the
    /// call could not be made", when the snapshot itself has nothing to say.
    ///
    /// `INVALID_CONFIG` is the one that matters and the one that looks least
    /// like a verdict. `request_sync` returns it when no licence key is
    /// stored for the tenant — and the SDK deletes that key as part of
    /// deactivating. So after `nexkeyctl --deactivate` (or any deactivation
    /// performed on this machine) the app's own SDK reports exactly this: no
    /// key, no receipt, nothing here. That is a fact about the seat, not a
    /// failure, and treating it as a failure is what left the UI showing
    /// "Active" for a licence whose plugin had already stopped rendering.
    private func syncFailureStatus(_ result: NexKeyRuntimeResult) -> LicenseValidationStatus {
        switch result {
        case NEXKEYRUNTIME_INVALID_CONFIG, NEXKEYRUNTIME_E_NO_RECEIPT, NEXKEYRUNTIME_E_ACTIVATION_NOT_FOUND:
            return .deactivatedRemotely
        case NEXKEYRUNTIME_OK:
            // The sync ran and the handle still holds no activation. Nothing
            // was taken away that this machine ever had — a licence that was
            // never activated here reads the same way — so this stays the
            // "no information" answer it has always been.
            return .notActivated
        default:
            return .error(AppMessages.text(.sdkSyncFailed, resultName(result)))
        }
    }

    // MARK: - License Info

    func getLicenseInfo(key: String, product: AppProduct) async throws -> LicenseInfo? {
        guard productDataResolver.entry(for: product.productID) != nil else {
            return nil
        }
        return await withCheckedContinuation { continuation in
            sdkQueue.async { [self] in
                guard let ctx = context(for: product) else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: readLicenseInfo(expectedKey: key, context: ctx))
            }
        }
    }

    private func readLicenseInfo(expectedKey: String, context: NexKeyHandleContext) -> LicenseInfo? {
        // The ABI never hands the raw key back, so the only way to confirm a
        // local receipt belongs to THIS key (and not a stale one from a
        // different license on the same machine) is the in-memory cache set
        // by `activate()`. No cache — e.g. a fresh launch — means "cannot
        // tell", and that must not read as a match.
        guard context.lastActivatedKey == expectedKey else {
            return nil
        }

        _ = nexkeyruntime_license_load_local(context.handle)
        var snapshot = NexKeyRuntimeLicenseSnapshot()
        snapshot.struct_size = MemoryLayout<NexKeyRuntimeLicenseSnapshot>.size
        guard nexkeyruntime_license_get_snapshot(context.handle, &snapshot) == NEXKEYRUNTIME_OK else {
            return nil
        }

        switch snapshot.status {
        case NEXKEYRUNTIME_LICENSE_ACTIVE, NEXKEYRUNTIME_LICENSE_OFFLINE_GRACE:
            break
        default:
            return nil
        }

        let editionLabel = cString(from: snapshot.edition)
        return LicenseInfo(edition: LicenseEditionType(fromMetadata: editionLabel))
    }

    // MARK: - Activated Key

    func activatedKey(for product: AppProduct) async -> String? {
        await withCheckedContinuation { continuation in
            sdkQueue.async { [self] in
                guard let ctx = handles[product.productID] else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: activatedKeySync(context: ctx))
            }
        }
    }

    private func activatedKeySync(context: NexKeyHandleContext) -> String? {
        guard let cachedKey = context.lastActivatedKey else { return nil }

        _ = nexkeyruntime_license_load_local(context.handle)
        var snapshot = NexKeyRuntimeLicenseSnapshot()
        snapshot.struct_size = MemoryLayout<NexKeyRuntimeLicenseSnapshot>.size
        guard nexkeyruntime_license_get_snapshot(context.handle, &snapshot) == NEXKEYRUNTIME_OK else {
            return nil
        }
        // ONLY the two statuses that mean "there is no local state here at
        // all" withhold the key. Everything else — suspended, revoked,
        // expired, the seat released elsewhere — IS local state about this
        // key, and saying "I don't know that key" about it is how the caller
        // ends up discarding the exact verdict it asked for.
        //
        // This used to return the key only for ACTIVE/OFFLINE_GRACE, which
        // made the answer circular: `LicenseWorkflowCoordinator` calls
        // `syncActivation()` first and this second, so any status the sync
        // just DOWNGRADED to made this return nil, `sdkOwnsThisKey` false,
        // and the fresh verdict was dropped on the floor. A licence
        // deactivated anywhere but this app then stayed "Active" forever.
        // `LexActivatorProvider` never had the bug: `GetLicenseKey` answers
        // regardless of health, which is what the protocol asks for.
        switch snapshot.status {
        case NEXKEYRUNTIME_LICENSE_NOT_ACTIVATED, NEXKEYRUNTIME_LICENSE_UNKNOWN:
            return nil
        default:
            return cachedKey
        }
    }

    // MARK: - Ownership across relaunches

    func localActivationIdentifier(for product: AppProduct) async -> String? {
        guard productDataResolver.entry(for: product.productID) != nil else { return nil }
        return await withCheckedContinuation { continuation in
            sdkQueue.async { [self] in
                guard let ctx = context(for: product) else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: localActivationIdentifierSync(context: ctx))
            }
        }
    }

    private func localActivationIdentifierSync(context: NexKeyHandleContext) -> String? {
        _ = nexkeyruntime_license_load_local(context.handle)
        var snapshot = NexKeyRuntimeLicenseSnapshot()
        snapshot.struct_size = MemoryLayout<NexKeyRuntimeLicenseSnapshot>.size
        guard nexkeyruntime_license_get_snapshot(context.handle, &snapshot) == NEXKEYRUNTIME_OK else {
            return nil
        }
        // Bounded by the tuple's own size rather than by a NUL. The SDK does
        // terminate it (`copyText`, LicenseHandle.cpp), but a fixed-size C
        // buffer read with `String(cString:)` is one upstream change away
        // from running off the end, and nothing here needs that risk.
        let identifier = withUnsafeBytes(of: snapshot.activation_id) { raw -> String in
            String(decoding: raw.prefix(while: { $0 != 0 }), as: UTF8.self)
        }
        return identifier.isEmpty ? nil : identifier
    }

    func adoptLocalActivation(key: String, activationId: String?, for product: AppProduct) async -> Bool {
        guard productDataResolver.entry(for: product.productID) != nil else { return false }
        return await withCheckedContinuation { continuation in
            sdkQueue.async { [self] in
                guard let ctx = context(for: product) else {
                    continuation.resume(returning: false)
                    return
                }
                // Already answered in this process — `activate()` set it, and
                // the in-memory answer is the stronger one.
                if let cached = ctx.lastActivatedKey {
                    continuation.resume(returning: cached == key)
                    return
                }
                // Nothing to match against: refusing is what keeps this from
                // degrading into "adopt whatever receipt is lying around".
                guard let activationId, !activationId.isEmpty,
                      let local = localActivationIdentifierSync(context: ctx),
                      local == activationId else {
                    continuation.resume(returning: false)
                    return
                }
                ctx.lastActivatedKey = key
                continuation.resume(returning: true)
            }
        }
    }

    // MARK: - Machine Fingerprint

    func machineFingerprint() -> String {
        // Never reimplemented: this must read the identical `IOPlatformUUID`
        // the legacy path (`MachineFingerprint.swift`) and the SDK's own
        // `hardware_id_apple.cpp` both read — it is what lets the backend
        // derive the SDK's machine binding from the legacy fingerprint
        // server-side (D42), with no coordination from this app beyond
        // calling `migrate-binding` at the right step.
        MachineFingerprint.generate()
    }

    // MARK: - Status mapping

    private func validationStatus(for status: NexKeyRuntimeLicenseStatus) -> LicenseValidationStatus {
        switch status {
        case NEXKEYRUNTIME_LICENSE_ACTIVE:
            return .genuine
        case NEXKEYRUNTIME_LICENSE_OFFLINE_GRACE:
            return .genuineGracePeriod
        case NEXKEYRUNTIME_LICENSE_EXPIRED, NEXKEYRUNTIME_LICENSE_OFFLINE_GRACE_EXPIRED:
            return .expired
        case NEXKEYRUNTIME_LICENSE_SUSPENDED:
            return .suspended
        case NEXKEYRUNTIME_LICENSE_REVOKED:
            return .revoked
        // NOT `.revoked`, which it used to share a branch with. The licence is
        // fine; only this machine's seat was released, and the user can take
        // it back by activating again. Reporting revocation would set
        // `isRevoked` and steer the UI to the terminal panel, which offers no
        // way back from something that is not terminal.
        case NEXKEYRUNTIME_LICENSE_ACTIVATION_REMOVED:
            return .deactivatedRemotely
        case NEXKEYRUNTIME_LICENSE_NOT_ACTIVATED, NEXKEYRUNTIME_LICENSE_UNKNOWN:
            return .notActivated
        default:
            return .error(statusName(status))
        }
    }

    private func statusName(_ status: NexKeyRuntimeLicenseStatus) -> String {
        switch status {
        case NEXKEYRUNTIME_LICENSE_UNKNOWN: return "UNKNOWN"
        case NEXKEYRUNTIME_LICENSE_NOT_ACTIVATED: return "NOT_ACTIVATED"
        case NEXKEYRUNTIME_LICENSE_ACTIVATING: return "ACTIVATING"
        case NEXKEYRUNTIME_LICENSE_ACTIVE: return "ACTIVE"
        case NEXKEYRUNTIME_LICENSE_OFFLINE_GRACE: return "OFFLINE_GRACE"
        case NEXKEYRUNTIME_LICENSE_OFFLINE_GRACE_EXPIRED: return "OFFLINE_GRACE_EXPIRED"
        case NEXKEYRUNTIME_LICENSE_EXPIRED: return "EXPIRED"
        case NEXKEYRUNTIME_LICENSE_SUSPENDED: return "SUSPENDED"
        case NEXKEYRUNTIME_LICENSE_REVOKED: return "REVOKED"
        case NEXKEYRUNTIME_LICENSE_ACTIVATION_REMOVED: return "ACTIVATION_REMOVED"
        case NEXKEYRUNTIME_LICENSE_DEVICE_MISMATCH: return "DEVICE_MISMATCH"
        case NEXKEYRUNTIME_LICENSE_CERTIFICATE_INVALID: return "CERTIFICATE_INVALID"
        case NEXKEYRUNTIME_LICENSE_CLOCK_ROLLBACK: return "CLOCK_ROLLBACK"
        case NEXKEYRUNTIME_LICENSE_SERVICE_UNAVAILABLE: return "SERVICE_UNAVAILABLE"
        case NEXKEYRUNTIME_LICENSE_INTERNAL_ERROR: return "INTERNAL_ERROR"
        default: return "UNKNOWN(\(status.rawValue))"
        }
    }

    private func resultName(_ result: NexKeyRuntimeResult) -> String {
        "NexKeyRuntimeResult(\(result.rawValue))"
    }

    /// Reads a fixed-size C `char[]` field (imported by Swift as a tuple) as
    /// a `String`, stopping at the first NUL — the same layout `snapshot.edition`
    /// and `snapshot.activation_id` use.
    private func cString<T>(from value: T) -> String {
        withUnsafeBytes(of: value) { raw in
            guard let base = raw.baseAddress else { return "" }
            return String(cString: base.assumingMemoryBound(to: CChar.self))
        }
    }
}
