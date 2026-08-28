import Foundation
#if DEBUG
import OSLog
#endif

struct ActivationPreparation {
    let key: String
    let product: AppProduct
    let edition: LicenseEdition
    let activationUsage: String
}

struct InstallationValidationDetails {
    let product: AppProduct
    let edition: LicenseEdition
    let skipLocalActivation: Bool
    let activationUsage: String
    let productData: String?
    let releases: [ReleaseInfo]
    let message: LicenseOperationMessage?
    /// Additive (Fase 5) — see `LicenseBackendValidation.runtime`.
    let runtime: LicenseRuntime
    let tenantId: String?
}

enum InstallationExecutionResult {
    case success(installedProduct: AppProduct, installedVersion: String, installedBundleNames: [String], allReleases: [ReleaseVersionInfo], message: LicenseOperationMessage?)
    case failure(String)
}

enum DeactivationExecutionResult {
    case success(updatedUsage: String)
    case failure(String)
}

private enum DeactivationRoute {
    case backendOnly(updatedUsage: String)
    /// Carries the runtime the ROUTE was decided from, which is not always
    /// `license.runtime`: when the stored value is stale or was never
    /// recorded, `deactivationRoute` falls back to the backend's answer, and
    /// that is the one the provider has to be resolved with. Picking the
    /// provider from `license.runtime` after routing on the backend's would
    /// send a NexKey deactivation to `LexActivatorProvider`.
    case sdk(product: AppProduct, runtime: LicenseRuntime?)
}

enum LicenseRefreshResult {
    case success([PluginLicenseItem])
    case fallback([PluginLicenseItem], BackendFallbackNotice?)
}

final class LicenseWorkflowCoordinator: @unchecked Sendable {
    #if DEBUG
    private static let logger = Logger(subsystem: "MCAppsTools", category: "LicenseWorkflow")
    #endif

    private let licenseBackend: LicenseBackendProvider
    private let runtimeRouter: LicenseRuntimeRouter
    private let releaseProvider: ReleaseProvider
    private let pluginInstaller: PluginInstaller
    private let licenseStore: LicenseStore
    private let productCredentialStore: ProductCredentialStore
    private let availableProducts: [AppProduct]

    init(
        licenseBackend: LicenseBackendProvider? = nil,
        runtimeRouter: LicenseRuntimeRouter = LicenseRuntimeRouter(),
        releaseProvider: ReleaseProvider? = nil,
        pluginInstaller: PluginInstaller = PluginInstaller(),
        licenseStore: LicenseStore = LicenseStore(),
        productCredentialStore: ProductCredentialStore = ProductCredentialStore(),
        availableProducts: [AppProduct] = AppProductCatalog.configuredProducts()
    ) {
        let defaultLicenseBackend = AppLicenseBackendProvider()
        self.licenseBackend = licenseBackend ?? defaultLicenseBackend
        self.runtimeRouter = runtimeRouter
        self.releaseProvider = releaseProvider ?? AppReleaseProvider(licenseProvider: defaultLicenseBackend)
        self.pluginInstaller = pluginInstaller
        self.licenseStore = licenseStore
        self.productCredentialStore = productCredentialStore
        self.availableProducts = availableProducts
    }

    func products() -> [AppProduct] {
        availableProducts
    }

    /// Fire-and-forget wake-up for hibernating backends. Delegated to the
    /// active `LicenseBackendProvider` so alternate implementations stay
    /// no-op via the protocol default.
    func warmUpBackend() async {
        await licenseBackend.warmUp()
    }

    /// Latest published client release for the current platform, or nil when
    /// the backend is unreachable. Best-effort by contract: callers should
    /// treat nil as "no update" without surfacing errors.
    func fetchLatestApp() async -> AppLatestInfo? {
        await licenseBackend.fetchLatestApp()
    }

    func saveLicenses(_ licenses: [PluginLicenseItem]) throws {
        try licenseStore.saveLicenses(licenses.map { $0.toPersisted() })
    }

    func loadCachedLicenses() throws -> [PluginLicenseItem] {
        let persisted = try licenseStore.loadLicenses()
        return persisted.map(PluginLicenseItem.fromCachedPersisted)
    }

    /// Detects locally-stale licenses where the encrypted credential file
    /// (`State/Records/*.dat`) was removed out-of-band and folds them into
    /// the `.deactivating` UI state. The deactivated panel exposes "Retry
    /// Installation" / "Remove Key", so the user lands on a coherent recovery
    /// surface instead of clicking Deactivate and tripping the SDK's
    /// `sdkProductConfigurationMissing` error mid-flow.
    ///
    /// File presence is the only signal here because it's authoritative for
    /// local-state integrity. The "SDK lost its activation" case is already
    /// owned by `refreshFromSDKOnly` and `refreshLicenses` — both run right
    /// after this in the boot path and rely on the backend as the source of
    /// truth, which avoids false positives when `GetLicenseKey` returns nil
    /// transiently. `skipLocalActivation == true` licenses use the same file
    /// check (the `.dat` still backs the retained key), they just never had
    /// an SDK activation to clean up.
    func reconcileLocalLicenseState(_ licenses: [PluginLicenseItem]) async -> [PluginLicenseItem] {
        var result = licenses

        for index in result.indices {
            let license = result[index]

            if license.lifecycleState == .deactivating || license.isRevoked {
                continue
            }

            guard !licenseStore.licenseKeyExists(for: license.id) else {
                continue
            }

            #if DEBUG
            Self.logger.debug("reconcile: forcing deactivating state productID=\(license.product.productID, privacy: .public) skipLocalActivation=\(license.skipLocalActivation, privacy: .public)")
            #endif

            // Best-effort SDK cleanup. When `productData` was also wiped the
            // call returns `sdkProductConfigurationMissing` — that's expected
            // here and intentionally swallowed; the goal is just to leave no
            // dangling activation behind for a subsequent retry. A `nil`
            // provider (runtime `.legacyBackendOnly`) means there was never a
            // local SDK activation to clean up in the first place.
            //
            // `skipLocalActivation` alone is not the right gate here: every
            // OpenKey response sets it `true` unconditionally (it predates
            // Fase 5 and only ever meant "no Cryptlex call"), so a NexKey-
            // routed license needs the same carve-out `runInstallation` uses.
            let needsSDKCleanup = license.runtime == .nexkeyRuntimeV1 || !license.skipLocalActivation
            if needsSDKCleanup, let provider = runtimeRouter.provider(for: license.runtime) {
                _ = await provider.deactivate(product: license.product)
            }

            result[index].activatedLicenseKey = nil
            result[index].availableVersion = nil
            // The SDK activation this pointed at was just torn down (or was
            // already gone). Keeping the id would leave the record naming
            // something that no longer exists — harmless, since adopting
            // requires a receipt that actually carries it, but a record that
            // lies about its own state is how the next reader gets confused.
            result[index].activationId = nil
            result[index].lifecycleState = .deactivating
            if result[index].deactivationDate == nil {
                result[index].deactivationDate = currentTimestamp()
            }
        }

        return result
    }

    /// Low-cost status poll that queries only the Cryptlex SDK (no backend hit).
    /// Targets licenses actually activated on this machine where the SDK has a
    /// local record — so revocations/suspensions surface in seconds without
    /// burning the backend's 5/min-per-fingerprint budget.
    ///
    /// Returns `(updated, changedKeys)`: callers can use `changedKeys` to
    /// decide whether to escalate to a single-key backend `/sync` to pull
    /// fresh releases/messages for the affected licenses.
    func refreshFromSDKOnly(_ currentLicenses: [PluginLicenseItem]) async -> (updated: [PluginLicenseItem], changedKeys: [String]) {
        var refreshed = currentLicenses
        var changedKeys: [String] = []
        var inspected = 0

        for index in refreshed.indices {
            let license = refreshed[index]

            // Eligible states: anything where the SDK still has local
            // activation data and can give an authoritative answer.
            //   - active / updateAvailable: catch downgrades (suspended/revoked/expired).
            //   - suspended: catch reinstatements back to active.
            // Revoked/deactivating already wiped `activatedLicenseKey`, so the
            // SDK cannot recover them — the backend heartbeat owns that path.
            let isEligibleState = license.lifecycleState == .active
                || license.lifecycleState == .updateAvailable
                || license.lifecycleState == .suspended
            guard !license.isRevoked,
                  license.edition != .beta,
                  isEligibleState,
                  let licenseKey = license.activatedLicenseKey else {
                continue
            }

            let product = license.product
            guard let provider = runtimeRouter.provider(for: license.runtime) else {
                continue
            }
            // Re-establishes ownership after a relaunch before asking. The
            // NexKey ABI never hands a raw key back, so `activatedKey` can
            // only answer from an in-memory cache `activate()` filled — which
            // dies with the process. Every launch therefore used to skip this
            // poll entirely for NexKey-routed licences, leaving the 15-minute
            // backend heartbeat as the only detector. A no-op for Cryptlex.
            let ownsThisKey = await provider.adoptLocalActivation(
                key: licenseKey.unsigned,
                activationId: license.activationId,
                for: product
            )
            guard ownsThisKey else {
                #if DEBUG
                Self.logger.debug("SDK poll: skipping productID=\(product.productID, privacy: .public) — SDK state is not about this key")
                #endif
                continue
            }

            inspected += 1
            // SyncLicenseActivation() is a blocking HTTP roundtrip to Cryptlex
            // — the only authoritative source. IsLicenseGenuine() returns the
            // local cached signature first and only schedules a server sync
            // in the background, so falling back to it would inject stale
            // state into the UI (which is exactly the "sometimes fast, sometimes
            // slow" symptom we were debugging). If the authoritative call
            // fails, skip this cycle and let the next poll retry.
            let syncStatus = await provider.syncActivation(product: product)

            #if DEBUG
            Self.logger.debug("SDK poll: productID=\(product.productID, privacy: .public) status=\(String(describing: syncStatus), privacy: .public)")
            #endif

            switch syncStatus {
            case .genuine, .genuineGracePeriod:
                // Reinstatement: license was suspended and is now back to
                // active. Safe to upgrade locally because SyncLicenseActivation
                // is authoritative (HTTP roundtrip, not cache). Backend
                // refresh that follows reconciles releases/usage/messages.
                if refreshed[index].lifecycleState == .suspended {
                    refreshed[index].lifecycleState = .active
                    changedKeys.append(licenseKey)
                }
                continue

            case .suspended:
                if refreshed[index].lifecycleState != .suspended {
                    refreshed[index].lifecycleState = .suspended
                    changedKeys.append(licenseKey)
                }

            case .revoked:
                refreshed[index].activatedLicenseKey = nil
                refreshed[index].availableVersion = nil
                refreshed[index].isRevoked = true
                refreshed[index].lifecycleState = .deactivating
                if refreshed[index].deactivationDate == nil {
                    refreshed[index].deactivationDate = currentTimestamp()
                }
                changedKeys.append(licenseKey)

            case .expired:
                // Treat as terminal locally; backend sync will confirm the
                // domain code (license_expired vs license_unavailable).
                refreshed[index].activatedLicenseKey = nil
                refreshed[index].availableVersion = nil
                refreshed[index].lifecycleState = .deactivating
                changedKeys.append(licenseKey)

            case .deactivatedRemotely:
                // The seat was released somewhere else — nexkeyctl, the
                // backOffice, an offline proof, another admin. NOT a
                // revocation: the licence is still good and activating again
                // is a legitimate move, so `isRevoked` stays false and the
                // user lands on the deactivated panel with Retry Installation
                // rather than the terminal one.
                //
                // This is the case that used to be invisible. It arrived as
                // `.notActivated` — indistinguishable from a failed call —
                // and fell into the branch below that skips the cycle.
                refreshed[index].activatedLicenseKey = nil
                refreshed[index].availableVersion = nil
                refreshed[index].lifecycleState = .deactivating
                if refreshed[index].deactivationDate == nil {
                    refreshed[index].deactivationDate = currentTimestamp()
                }
                changedKeys.append(licenseKey)

            case .notActivated, .error:
                // Authoritative call failed (network, Cryptlex rate limit,
                // LA_FAIL, etc.). Do NOT fall back to IsLicenseGenuine —
                // its cached answer is the root cause of the perceived delay.
                #if DEBUG
                Self.logger.debug("SDK poll: skipping cycle productID=\(product.productID, privacy: .public) — authoritative sync unavailable")
                #endif
                continue
            }
        }

        #if DEBUG
        Self.logger.debug("SDK poll done: inspected=\(inspected, privacy: .public) changed=\(changedKeys.count, privacy: .public)")
        #endif
        return (refreshed, changedKeys)
    }

    func refreshLicenses(_ currentLicenses: [PluginLicenseItem], allowsBackendSync: Bool = true) async -> LicenseRefreshResult {
        guard !currentLicenses.isEmpty else {
            return .fallback(currentLicenses, nil)
        }

        var refreshed = currentLicenses
        var sdkStatusesByKey: [String: LicenseValidationStatus] = [:]
        var backendRequests: [LicenseBackendSyncRequest] = []

        for index in refreshed.indices {
            if refreshed[index].isRevoked {
                refreshed[index].activatedLicenseKey = nil
                refreshed[index].availableVersion = nil
                refreshed[index].lifecycleState = .deactivating
                if refreshed[index].deactivationDate == nil {
                    refreshed[index].deactivationDate = currentTimestamp()
                }
                continue
            }

            if refreshed[index].lifecycleState == .deactivating {
                continue
            }

            let product = refreshed[index].product
            guard let licenseKey = refreshed[index].lastKnownLicenseKey ?? refreshed[index].activatedLicenseKey else {
                continue
            }

            let sdkStatus: LicenseValidationStatus?

            if let provider = runtimeRouter.provider(for: refreshed[index].runtime) {
                // OWNERSHIP IS SETTLED BEFORE THE SYNC, not after it, and the
                // order is the whole fix. `syncActivation` legitimately
                // downgrades the SDK's status — that is what it is for — and
                // `activatedKey` is then asked whether the SDK knows this
                // key. Asking afterwards used to be circular: the downgrade
                // itself made `activatedKey` answer nil (it filtered on
                // health), `sdkOwnsThisKey` went false, and the verdict the
                // sync had just fetched was discarded. Every deactivation
                // performed outside this app died right here.
                //
                // `activatedKey` no longer filters on health either — see
                // NexKeyRuntimeProvider — so both halves of that loop are cut.
                var sdkOwnsThisKey = await provider.adoptLocalActivation(
                    key: licenseKey.unsigned,
                    activationId: refreshed[index].activationId,
                    for: product
                )
                let syncStatus = await provider.syncActivation(product: product)

                // Adopting a SECOND time, after the sync, is not redundant:
                // the first attempt has nothing to match against when the
                // receipt is missing but the licence key is still stored, and
                // that sync is exactly what fetches a fresh certificate back
                // onto disk. Re-asking `activatedKey` instead would be dead
                // code — only `activate()` and this call ever populate the
                // cache it reads.
                if !sdkOwnsThisKey {
                    sdkOwnsThisKey = await provider.adoptLocalActivation(
                        key: licenseKey.unsigned,
                        activationId: refreshed[index].activationId,
                        for: product
                    )
                }

                if sdkOwnsThisKey {
                    // Recorded lazily, here, rather than plumbed back out of
                    // runInstallation: this runs right after an install (the
                    // in-memory cache is still warm, so ownership is certain)
                    // and it also back-fills licences activated before the
                    // field existed, the next time one of them is confirmed.
                    if let identifier = await provider.localActivationIdentifier(for: product) {
                        refreshed[index].activationId = identifier
                    }
                    if isReliableSDKStatus(syncStatus) {
                        sdkStatus = syncStatus
                    } else {
                        let validationStatus = await provider.validate(product: product)
                        sdkStatus = isReliableSDKStatus(validationStatus) ? validationStatus : nil
                    }
                } else {
                    sdkStatus = nil
                }
            } else {
                sdkStatus = nil
            }

            if let sdkStatus {
                sdkStatusesByKey[licenseKey] = sdkStatus
            }

            backendRequests.append(LicenseBackendSyncRequest(
                key: licenseKey,
                product: product
            ))
        }

        let backendSyncs: [LicenseBackendSync]
        if allowsBackendSync {
            switch await licenseBackend.syncLicenses(backendRequests) {
            case .success(let syncs):
                backendSyncs = syncs
            case .failure(let error):
                return .fallback(currentLicenses, fallbackNotice(for: error))
            }
        } else {
            backendSyncs = []
        }
        let backendSyncByKey = Dictionary(uniqueKeysWithValues: backendSyncs.map { ($0.key, $0) })

        for index in refreshed.indices {
            if refreshed[index].isRevoked || refreshed[index].lifecycleState == .deactivating {
                continue
            }

            let product = refreshed[index].product
            guard let licenseKey = refreshed[index].lastKnownLicenseKey ?? refreshed[index].activatedLicenseKey else {
                continue
            }

            let backendSync = backendSyncByKey[licenseKey]
            let localStatus = sdkStatusesByKey[licenseKey]
                ?? backendSync.map { validationStatus(for: $0.status) }

            // THE BACKEND IS THE AUTHORITY ON SEATS, and this is the only
            // signal that survives when the local SDK state is gone too —
            // which is exactly what a deactivation performed on this machine
            // leaves behind (the SDK deletes its own receipt and stored key).
            //
            // It outranks `.genuine` deliberately: a local receipt stays
            // cryptographically valid for its whole offline window, so an app
            // trusting it would keep showing "Active" for up to 30 days after
            // the seat was released. It does NOT outrank a worse verdict about
            // the licence itself — a revoked or suspended licence is a bigger
            // fact than a released seat, and the UI for it is different.
            //
            // `.unknown` changes nothing, by construction. See
            // MachineActivationState.
            let resolvedStatus: LicenseValidationStatus? = {
                guard backendSync?.activation == .removed else { return localStatus }
                switch localStatus {
                case .some(.revoked), .some(.suspended), .some(.expired):
                    return localStatus
                default:
                    return .deactivatedRemotely
                }
            }()

            if let resolvedProduct = backendSync?.product {
                refreshed[index].pluginName = resolvedProduct.displayName
                refreshed[index].product = resolvedProduct
            }

            // Reconcile the install-time SDK skip flag from backend sync so
            // licenses persisted before the field existed can recover, and so
            // any backend-side policy change propagates without a reinstall.
            if let skipLocal = backendSync?.skipLocalActivation {
                refreshed[index].skipLocalActivation = skipLocal
            }

            // The runtime needs the SAME reconciliation, and not having it was
            // the other half of the silent-deactivate bug. `runtime` used to be
            // written at install time only, by the paths that pass a
            // `licenseID` — so a license installed before the field existed, or
            // updated through `installUpdate`/`installPreviousVersion`, kept
            // `nil` forever while `skipLocalActivation` was refreshed to `true`
            // on every heartbeat. That pair is precisely what routed a
            // NexKey-backed license into the backend-only shortcut in
            // `deactivateLicense`. Every sync response already carries
            // `licensing.runtime`, and for a generation-1 tenant it is resolved
            // PER REQUEST from `X-NexKey-Capabilities`, not stored per tenant —
            // so the wire answer is the only current one, and a cached copy is
            // by nature a stale one.
            if let syncedRuntime = backendSync?.runtime {
                refreshed[index].runtime = syncedRuntime
            }
            if let syncedTenantId = backendSync?.tenantId {
                refreshed[index].tenantId = syncedTenantId
            }

            switch resolvedStatus {
            case .some(.genuine), .some(.genuineGracePeriod):
                let info = try? await runtimeRouter.provider(for: refreshed[index].runtime)?.getLicenseInfo(key: licenseKey, product: product)
                if let info = info ?? nil {
                    refreshed[index].edition = LicenseEdition(from: info.edition)
                }
                refreshed[index].activationUsage = backendSync?.activationUsage ?? refreshed[index].activationUsage
                refreshed[index].activatedLicenseKey = licenseKey
                refreshed[index].isRevoked = false
                if refreshed[index].lifecycleState != .updateAvailable {
                    refreshed[index].lifecycleState = .active
                }

            case .some(.suspended):
                let info = try? await runtimeRouter.provider(for: refreshed[index].runtime)?.getLicenseInfo(key: licenseKey, product: product)
                if let info = info ?? nil {
                    refreshed[index].edition = LicenseEdition(from: info.edition)
                }
                refreshed[index].activationUsage = backendSync?.activationUsage ?? refreshed[index].activationUsage
                refreshed[index].activatedLicenseKey = licenseKey
                refreshed[index].isRevoked = false
                refreshed[index].lifecycleState = .suspended

            case .some(.revoked):
                refreshed[index].activatedLicenseKey = nil
                refreshed[index].availableVersion = nil
                refreshed[index].isRevoked = true
                refreshed[index].lifecycleState = .deactivating
                if refreshed[index].deactivationDate == nil {
                    refreshed[index].deactivationDate = currentTimestamp()
                }

            case .some(.deactivatedRemotely):
                // The seat is gone but the licence is not: no `isRevoked`, and
                // a deactivation date so the panel reads as a deactivation
                // rather than as an unexplained blank. Activating again is a
                // legitimate move from here.
                refreshed[index].activatedLicenseKey = nil
                refreshed[index].availableVersion = nil
                refreshed[index].isRevoked = false
                refreshed[index].activationId = nil
                refreshed[index].lifecycleState = .deactivating
                if refreshed[index].deactivationDate == nil {
                    refreshed[index].deactivationDate = currentTimestamp()
                }

            case .some:
                refreshed[index].activatedLicenseKey = nil
                refreshed[index].availableVersion = nil
                refreshed[index].isRevoked = false
                refreshed[index].lifecycleState = .deactivating

            case nil:
                break
            }

            let skipReleaseCheck = refreshed[index].lifecycleState == .suspended
                || refreshed[index].lifecycleState == .deactivating

            if allowsBackendSync, !skipReleaseCheck, let installedVersion = refreshed[index].installedVersion {
                let releases = (backendSync?.releases.isEmpty == false
                    ? backendSync?.releases ?? []
                    : ((try? await releaseProvider.listReleases(productID: refreshed[index].product.productID)) ?? []))
                    .filter(\.isCurrentPlatform)

                if let latestRelease = releases.first {
                    if compareVersions(latestRelease.version, installedVersion) == .orderedDescending {
                        refreshed[index].availableVersion = latestRelease.version
                        refreshed[index].lifecycleState = .updateAvailable
                    } else {
                        refreshed[index].availableVersion = nil
                        refreshed[index].lifecycleState = .active
                    }

                    let otherReleases = releases
                        .filter { $0.version != installedVersion }
                        .map { ReleaseVersionInfo(version: $0.version, channel: $0.channel) }
                    refreshed[index].previousVersions = sortedReleases(
                        mergeReleases(refreshed[index].previousVersions, otherReleases)
                    )
                    refreshed[index].isInitialStatusLoad = true
                }
            }
        }

        return .success(refreshed)
    }

    func prepareActivationKeyOffline(
        _ rawKey: String,
        product: AppProduct,
        existingLicenses: [PluginLicenseItem]
    ) -> Result<ActivationPreparation, LicenseOperationError> {
        let trimmedKey = rawKey.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmedKey.isEmpty else {
            return .failure(.local(AppMessages.text(.invalidKeyLocal)))
        }

        guard trimmedKey.isValidSignedLicenseKey else {
            return .failure(.local(AppMessages.text(.invalidKeyFormat)))
        }

        let alreadyExists = existingLicenses.contains {
            $0.activatedLicenseKey?.caseInsensitiveCompare(trimmedKey) == .orderedSame
                || $0.lastKnownLicenseKey?.caseInsensitiveCompare(trimmedKey) == .orderedSame
        }
        if alreadyExists {
            return .failure(.local(AppMessages.text(.keyAlreadyActivated)))
        }

        return .success(ActivationPreparation(key: trimmedKey, product: product, edition: .full, activationUsage: "--"))
    }

    private func validateInstallationLicense(
        key: String,
        activateOnMachine: Bool
    ) async -> Result<InstallationValidationDetails, LicenseOperationError> {
        switch await licenseBackend.validateInstallationLicense(
            key: key,
            activateOnMachine: activateOnMachine
        ) {
        case .success(let validation):
            // Cryptlex-only — see AppLicenseBackendProvider.validateInstallationLicense
            // for why a NexKeyRuntime-routed license must not persist this
            // field into productCredentialStore.
            if validation.runtime == .cryptlexLexActivatorV1, let productData = validation.productData {
                do {
                    try productCredentialStore.saveProductData(productData, for: validation.product.productID)
                } catch {
                    return .failure(.local(AppMessages.text(.productCredentialsSaveFailed)))
                }
            }

            return .success(InstallationValidationDetails(
                product: validation.product,
                edition: validation.edition,
                skipLocalActivation: validation.skipLocalActivation,
                activationUsage: validation.activationUsage,
                productData: validation.productData,
                releases: validation.releases,
                message: validation.message,
                runtime: validation.runtime,
                tenantId: validation.tenantId
            ))
        case .failure(let error):
            return .failure(error)
        }
    }

    func runInstallation(
        for product: AppProduct,
        targetVersion: String? = nil,
        licenseKey: String? = nil,
        activateOnMachine: Bool = false,
        existingLicenses: [PluginLicenseItem] = [],
        progress: @escaping @MainActor (InstallationStep, StepStatus, String?) -> Void,
        validatedLicense: @escaping @MainActor (InstallationValidationDetails) -> Void = { _ in },
        downloadProgress: @escaping @MainActor (DownloadStats) -> Void = { _ in }
    ) async -> InstallationExecutionResult {
        var installProduct = product
        var validatedReleases: [ReleaseInfo] = []
        var backendSuccessMessage: LicenseOperationMessage?
        var shouldSkipLocalActivation = false
        var installRuntime: LicenseRuntime?
        var installTransactions: [PluginInstallTransaction] = []

        for step in InstallationStep.allCases {
            await MainActor.run {
                progress(step, .pending, nil)
            }
        }

        await MainActor.run {
            progress(.validatingLicense, .inProgress, nil)
        }

        if let licenseKey {
            switch await validateInstallationLicense(
                key: licenseKey,
                activateOnMachine: activateOnMachine
            ) {
            case .success(let validationDetails):
                installProduct = validationDetails.product
                validatedReleases = validationDetails.releases
                backendSuccessMessage = validationDetails.message
                shouldSkipLocalActivation = validationDetails.skipLocalActivation
                installRuntime = validationDetails.runtime

                await MainActor.run {
                    validatedLicense(validationDetails)
                    progress(.validatingLicense, .completed, nil)
                }
            case .failure(let error):
                let detail = error.displayMessage
                await MainActor.run {
                    progress(.validatingLicense, .failed, detail)
                }
                return .failure(detail)
            }
        } else {
            let detail = AppMessages.text(.validateInvalidKey)
            await MainActor.run {
                progress(.validatingLicense, .failed, detail)
            }
            return .failure(detail)
        }

        await MainActor.run {
            progress(.downloadingRelease, .inProgress, nil)
        }

        let archiveURL: URL
        let installedVersion: String
        var allReleases: [ReleaseVersionInfo] = []
        do {
            let releases = (validatedReleases.isEmpty
                ? try await releaseProvider.listReleases(productID: installProduct.productID)
                : validatedReleases)
                .filter(\.isCurrentPlatform)
            allReleases = releases.map { ReleaseVersionInfo(version: $0.version, channel: $0.channel) }
            let release: ReleaseInfo
            if let targetVersion {
                guard let found = releases.first(where: { $0.version == targetVersion }) else {
                    throw PluginInstallerError.downloadFailed(AppMessages.text(.releaseVersionNotFound, targetVersion))
                }
                release = found
            } else {
                guard let latest = releases.first else {
                    throw PluginInstallerError.downloadFailed(AppMessages.text(.noReleasesAvailable))
                }
                release = latest
            }

            installedVersion = release.version
            #if DEBUG
            print("[Workflow] selected release id=\(release.id) name=\(release.name) version=\(release.version) channel=\(release.channel) totalFiles=\(release.totalFiles)")
            #endif
            archiveURL = try await releaseProvider.downloadRelease(
                releaseId: release.id,
                productID: installProduct.productID,
                licenseKey: licenseKey
            ) { event in
                if case .downloading(let stats) = event {
                    Task { @MainActor in
                        downloadProgress(stats)
                    }
                }
            }
            #if DEBUG
            let archiveSize = (try? FileManager.default.attributesOfItem(atPath: archiveURL.path)[.size] as? NSNumber)?.int64Value ?? -1
            print("[Workflow] download returned archive=\(archiveURL.path) size=\(archiveSize)")
            #endif
        } catch {
            let detail = AppMessages.text(.downloadFailed, userFacingDownloadMessage(for: error))
            await MainActor.run {
                progress(.downloadingRelease, .failed, detail)
            }
            return .failure(detail)
        }

        defer {
            Task {
                await pluginInstaller.cleanup()
            }
        }

        await MainActor.run {
            progress(.downloadingRelease, .completed, nil)
            progress(.installingPlugin, .inProgress, nil)
        }

        let ofxBundles: [URL]
        do {
            let extractDir = try await pluginInstaller.extractArchive(at: archiveURL)
            ofxBundles = try await pluginInstaller.findOFXBundles(in: extractDir)
            #if DEBUG
            print("[Workflow] OFX bundles found count=\(ofxBundles.count) names=\(ofxBundles.map(\.lastPathComponent).joined(separator: ", "))")
            #endif
            guard !ofxBundles.isEmpty else {
                throw PluginInstallerError.extractionFailed(AppMessages.text(.noOFXBundlesFound))
            }
        } catch {
            let detail = AppMessages.text(.extractFailed, userFacingExtractionMessage(for: error))
            await MainActor.run {
                progress(.installingPlugin, .failed, detail)
            }
            return .failure(detail)
        }

        await MainActor.run {
            progress(.installingPlugin, .inProgress, nil)
        }

        func failActivation(_ detail: String) async -> InstallationExecutionResult {
            if !installTransactions.isEmpty {
                do {
                    try await pluginInstaller.rollbackInstallTransactions(installTransactions)
                } catch {
                    let rollbackDetail = userFacingInstallationMessage(for: error)
                    let combined = "\(detail) Could not restore previous plugin files: \(rollbackDetail)"
                    await MainActor.run {
                        progress(.activatingLicense, .failed, combined)
                    }
                    return .failure(combined)
                }
            }

            await MainActor.run {
                progress(.activatingLicense, .failed, detail)
            }
            return .failure(detail)
        }

        var installedBundleNames: [String] = []
        do {
            let ext = ".ofx.bundle"
            let productSuffix = String(installProduct.productID
                .replacingOccurrences(of: "-", with: "")
                .prefix(6))
            let environmentSuffix = AppEnvironment.current.installedBundleNameSuffix
            for bundle in ofxBundles {
                let originalBundleName = bundle.lastPathComponent
                let originalBaseName = originalBundleName.hasSuffix(ext)
                    ? String(originalBundleName.dropLast(ext.count))
                    : originalBundleName
                var candidateBaseName = originalBaseName
                if let environmentSuffix {
                    candidateBaseName += "-\(environmentSuffix)"
                }
                let candidateBundleName = "\(candidateBaseName)\(ext)"
                let conflictExists = existingLicenses.contains { other in
                    other.product.productID != installProduct.productID
                        && other.installedBundleNames.contains(candidateBundleName)
                        && other.lifecycleState != .deactivating
                }

                var effectiveBaseName = originalBaseName
                if conflictExists {
                    effectiveBaseName += "-\(productSuffix)"
                }
                if let environmentSuffix {
                    effectiveBaseName += "-\(environmentSuffix)"
                }

                let effectiveBundleName = "\(effectiveBaseName)\(ext)"
                let transaction = try await pluginInstaller.installOFXBundleTransactional(from: bundle, bundleName: effectiveBundleName)
                installTransactions.append(transaction)
                installedBundleNames.append(effectiveBundleName)
            }
        } catch {
            var detail = AppMessages.text(.installFailed, userFacingInstallationMessage(for: error))
            if !installTransactions.isEmpty {
                do {
                    try await pluginInstaller.rollbackInstallTransactions(installTransactions)
                } catch {
                    detail += " Could not restore previous plugin files: \(userFacingInstallationMessage(for: error))"
                }
            }
            await MainActor.run {
                progress(.installingPlugin, .failed, detail)
            }
            return .failure(detail)
        }

        await MainActor.run {
            progress(.installingPlugin, .completed, nil)
            progress(.activatingLicense, .inProgress, nil)
        }

        // D42 — step 4, here and never earlier: download/install happen in
        // between steps 1 and 4, so migrating at validate time would rename
        // the row to a binding no installed plugin holds yet. Only meaningful
        // for the SDK path; the backend itself no-ops (`runtime_not_applicable`)
        // for anything else, so this is skipped locally as a pure optimization.
        if installRuntime == .nexkeyRuntimeV1, let licenseKey {
            await licenseBackend.migrateBinding(key: licenseKey)
        }

        // `skipLocalActivation` predates Fase 5 and is scoped to the Cryptlex
        // path only: every OpenKey response sets it `true` unconditionally
        // (verified against staging — it always has, legacy included, since
        // OpenKey never had a local Cryptlex activation to skip). A
        // NexKeyRuntime-routed license needs the opposite of what that flag
        // says here: D41 moved the real activation OFF `validate-installation`
        // and onto the SDK, so `runInstallation` — not a server flag — is what
        // must call it.
        let needsLocalActivation = installRuntime == .nexkeyRuntimeV1 || !shouldSkipLocalActivation

        // `activateOnMachine: false` NEEDED THE SAME CORRECTION AS
        // `skipLocalActivation`, and not getting it was a silent-unlicensed
        // bug. The flag means "this machine already holds its seat, do not
        // claim another" — installUpdate and installSpecificVersion both send
        // it. That is right for Cryptlex, where validate-installation is what
        // records the machine and a reinstall must not consume a second seat.
        //
        // On the NexKeyRuntime path it left NOBODY activating. D41 made
        // validate-installation a pre-check that writes nothing
        // (`seatOperationFor` -> 'precheck' -> syncLicense), so if the app also
        // skips the SDK call, an update finishes with no seat and no local
        // receipt — and the code below still marks `.activatingLicense`
        // `.completed` and returns success. The plugin installs, the app says
        // it activated, and the plugin refuses to render, with no error
        // anywhere to explain it.
        //
        // WHAT THE FLAG REALLY ASSERTS — "this machine already holds it" — is
        // a question the SDK can answer locally, so ask it instead of assuming
        // it. `validate()` is `load_local` plus a snapshot read: no network, no
        // seat. Only a machine that turns out NOT to hold the license activates,
        // which is exactly the case the flag was silently mishandling. A
        // machine that does hold it still skips, so a reinstall costs nothing,
        // and re-activating is safe anyway — the gateway upserts on the same
        // machine binding and answers E_PRODUCT_ACTIVATED, which maps to
        // `.alreadyActivatedOnThisMachine` and breaks through as success.
        //
        // An indeterminate result (`.error`) activates too: activation is
        // idempotent for a machine that already holds the seat, so guessing
        // "activate" costs nothing there, while guessing "skip" reintroduces
        // exactly this bug.
        var shouldActivateLocally = activateOnMachine
        if !shouldActivateLocally, installRuntime == .nexkeyRuntimeV1, licenseKey != nil,
           let activationProvider = runtimeRouter.provider(for: installRuntime) {
            switch await activationProvider.validate(product: installProduct) {
            case .genuine, .genuineGracePeriod:
                shouldActivateLocally = false
            default:
                shouldActivateLocally = true
            }
        }

        if shouldActivateLocally, needsLocalActivation, let licenseKey,
           let activationProvider = runtimeRouter.provider(for: installRuntime) {
            let activationStatus = await activationProvider.activate(key: licenseKey, product: installProduct)
            switch activationStatus {
            case .activated, .alreadyActivatedOnThisMachine:
                break
            case .revoked:
                let detail = AppMessages.text(.activationRevoked)
                return await failActivation(detail)
            case .suspended:
                let detail = AppMessages.text(.activationSuspended)
                return await failActivation(detail)
            case .noActivationsLeft:
                let detail = AppMessages.text(.activationLimitReached)
                return await failActivation(detail)
            case .invalidKey:
                let detail = AppMessages.text(.activationInvalidKey)
                return await failActivation(detail)
            case .expired:
                let detail = AppMessages.text(.activationExpired)
                return await failActivation(detail)
            case .error(let message):
                let detail = AppMessages.text(.activationFailed, message)
                return await failActivation(detail)
            }
        }

        await pluginInstaller.commitInstallTransactions(installTransactions)

        await MainActor.run {
            progress(.activatingLicense, .completed, nil)
        }

        return .success(
            installedProduct: installProduct,
            installedVersion: installedVersion,
            installedBundleNames: installedBundleNames,
            allReleases: allReleases,
            message: backendSuccessMessage
        )
    }

    func deactivateLicense(for license: PluginLicenseItem) async -> DeactivationExecutionResult {
        let key = license.lastKnownLicenseKey ?? license.activatedLicenseKey

        // Licenses installed with skipLocalActivation never had a Cryptlex
        // local activation — there is no productData on disk and calling the
        // SDK would fail with sdkProductConfigurationMissing. Skip straight to
        // the backend-driven usage refresh so the UI can finish the deactivate
        // flow cleanly.
        //
        // Every OpenKey response sets this `true` unconditionally (verified
        // against staging) — legacy OpenKey never had a local SDK to begin
        // with, but a NexKeyRuntime-routed license now does, and skipping
        // straight to a read-only usage refresh here would leave its seat
        // permanently consumed: only `NexKeyRuntimeProvider.deactivate()`
        // (reached via `deactivationRoute` below) actually releases it.
        //
        // ONLY `.legacyBackendOnly` MAY TAKE THIS SHORTCUT — "not NexKey" is
        // not the same question and was the bug. `skipLocalActivation` is
        // written by the OpenKey provider and nothing else (the Cryptlex path
        // always sends `false`), so `true` here PROVES an OpenKey tenant, and
        // an OpenKey tenant is never `.cryptlexLexActivatorV1`. A license
        // sitting at `.cryptlexLexActivatorV1` or `nil` with the flag set is
        // therefore not a Cryptlex license — it is a NexKey one whose runtime
        // this app never recorded (installed by a build predating the field,
        // or by `installUpdate`/`installPreviousVersion`, which used to drop
        // it), and `!= .nexkeyRuntimeV1` waved exactly that case through:
        // deactivate returned `.success`, the UI showed "deactivated", and no
        // request was ever sent — the seat stayed live on the server forever.
        // Anything not provably local-SDK-free now goes to
        // `deactivationRoute`, which asks the backend instead of guessing.
        if license.skipLocalActivation, license.runtime == .legacyBackendOnly {
            let updatedUsage: String
            if let key, !key.isEmpty {
                updatedUsage = await fetchActivationUsage(for: key)
            } else {
                updatedUsage = license.activationUsage
            }
            return .success(updatedUsage: updatedUsage)
        }

        let route = await deactivationRoute(for: license, key: key)
        switch route {
        case .backendOnly(let updatedUsage):
            return .success(updatedUsage: updatedUsage)
        case .sdk(let product, let runtime):
            guard let provider = runtimeRouter.provider(for: runtime) else {
                return .failure(AppMessages.text(.deactivateFailed, AppMessages.text(.sdkProductConfigurationMissing, license.product.displayName)))
            }
            let status = await provider.deactivate(product: product)
            return await finishSDKDeactivation(status, key: key, fallbackUsage: license.activationUsage)
        case nil:
            return .failure(AppMessages.text(.deactivateFailed, AppMessages.text(.sdkProductConfigurationMissing, license.product.displayName)))
        }
    }

    private func finishSDKDeactivation(
        _ status: LicenseDeactivationStatus,
        key: String?,
        fallbackUsage: String
    ) async -> DeactivationExecutionResult {

        switch status {
        case .deactivated, .notActivated:
            let updatedUsage: String
            if let key, !key.isEmpty {
                updatedUsage = await fetchActivationUsage(for: key)
            } else {
                updatedUsage = fallbackUsage
            }
            return .success(updatedUsage: updatedUsage)
        case .error(let detail):
            return .failure(AppMessages.text(.deactivateFailed, detail))
        }
    }

    private func deactivationRoute(for license: PluginLicenseItem, key: String?) async -> DeactivationRoute? {
        // NexKeyRuntimeProvider never populates `productCredentialStore` —
        // its configuration lives in `NexKeyRuntimeConfigurationStore`, a
        // separate key space, precisely so this check stays a Cryptlex-only
        // signal — so `hasStoredProductData` can never see it; the license's
        // own `runtime` is the signal for this path instead.
        if license.runtime == .nexkeyRuntimeV1 {
            return .sdk(product: license.product, runtime: .nexkeyRuntimeV1)
        }
        // Stored ProductData proves a local Cryptlex activation ONLY for a
        // license the Cryptlex path actually wrote, and `skipLocalActivation`
        // is how that is known: the Cryptlex branch always sends `false`, the
        // OpenKey branch always `true` (appClient — validation.ts vs
        // providers/openkey.ts). Gating on it keeps the offline deactivate
        // every pre-Fase-5 Cryptlex license depends on — no runtime recorded,
        // blob on disk, no network needed — while stopping a STALE blob from
        // hijacking the route. Stale ones exist: this app saved every
        // response's productData unconditionally until
        // `AppLicenseBackendProvider` learned to persist it for Cryptlex only,
        // so a NexKey-routed product can still have a Cryptlex-era blob on
        // disk. Unguarded, that blob answered "yes" here and sent the
        // deactivation to `LexActivatorProvider` — the wrong SDK, which
        // cannot release an OpenKey seat and, with no runtime recorded to
        // contradict it, was reached without the backend ever being asked.
        if !license.skipLocalActivation, hasStoredProductData(for: license.product) {
            return .sdk(product: license.product, runtime: license.runtime)
        }

        guard let key, !key.isEmpty else {
            return nil
        }

        switch await licenseBackend.syncLicenses([
            LicenseBackendSyncRequest(key: key, product: license.product)
        ]) {
        case .success(let syncs):
            guard let sync = syncs.first(where: { $0.key == key }) else {
                return nil
            }

            // Checked before `skipLocalActivation` on purpose: every OpenKey
            // sync response sets that flag `true` unconditionally, which
            // would otherwise route a NexKey-routed license to `.backendOnly`
            // and leave its seat unreleased.
            if sync.runtime == .nexkeyRuntimeV1 {
                return .sdk(product: sync.product, runtime: .nexkeyRuntimeV1)
            }

            if sync.skipLocalActivation == true {
                return .backendOnly(updatedUsage: sync.activationUsage)
            }

            if hasStoredProductData(for: sync.product) {
                return .sdk(product: sync.product, runtime: sync.runtime)
            }

            if hasStoredProductData(for: license.product) {
                return .sdk(product: license.product, runtime: sync.runtime)
            }

            return nil
        case .failure:
            return nil
        }
    }

    private func hasStoredProductData(for product: AppProduct) -> Bool {
        guard let productData = try? productCredentialStore.loadProductData(for: product.productID) else {
            return false
        }

        return !productData.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func uninstallPluginBundles(for license: PluginLicenseItem) async -> Result<Void, LicenseOperationError> {
        for bundleName in license.installedBundleNames {
            do {
                try await pluginInstaller.uninstallOFXBundle(bundleName: bundleName)
            } catch PluginInstallerError.authenticationCancelled {
                return .failure(.local(AppMessages.text(.installerAuthenticationCancelled)))
            } catch {
                let detail = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                return .failure(.local(detail))
            }
        }
        return .success(())
    }

    func latestReleaseVersion(for product: AppProduct) async -> String? {
        guard let release = try? await releaseProvider.latestRelease(productID: product.productID) else {
            return nil
        }
        return release.version
    }

    func allReleaseVersions(for product: AppProduct) async -> [String] {
        guard let releases = try? await releaseProvider.listReleases(productID: product.productID) else {
            return []
        }
        return releases.map(\.version)
    }

    func allReleases(for product: AppProduct) async -> [ReleaseVersionInfo] {
        guard let releases = try? await releaseProvider.listReleases(productID: product.productID) else {
            return []
        }
        return releases.map { ReleaseVersionInfo(version: $0.version, channel: $0.channel) }
    }

    func sortedReleases(_ releases: [ReleaseVersionInfo]) -> [ReleaseVersionInfo] {
        releases.sorted { compareVersions($0.version, $1.version) == .orderedDescending }
    }

    /// Merges two release lists, deduplicating by `version`. When a version
    /// appears in both, the entry from `incoming` wins so the freshest
    /// channel info from the backend overwrites any stale cached value.
    func mergeReleases(_ existing: [ReleaseVersionInfo], _ incoming: [ReleaseVersionInfo]) -> [ReleaseVersionInfo] {
        var merged: [String: ReleaseVersionInfo] = [:]
        for item in existing {
            merged[item.version] = item
        }
        for item in incoming {
            merged[item.version] = item
        }
        return Array(merged.values)
    }

    func fetchActivationUsage(for key: String) async -> String {
        await licenseBackend.activationUsage(for: key)
    }

    func highestVersion(in versions: [String]) -> String? {
        sortedVersions(Array(Set(versions))).first
    }

    func sortedVersions(_ versions: [String]) -> [String] {
        versions.sorted { compareVersions($0, $1) == .orderedDescending }
    }

    func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let lhsParts = numericVersionComponents(lhs)
        let rhsParts = numericVersionComponents(rhs)
        let maxCount = max(lhsParts.count, rhsParts.count)

        for index in 0..<maxCount {
            let left = index < lhsParts.count ? lhsParts[index] : 0
            let right = index < rhsParts.count ? rhsParts[index] : 0

            if left > right {
                return .orderedDescending
            }

            if left < right {
                return .orderedAscending
            }
        }

        return .orderedSame
    }

    /// Tolerates common version-string variants ("v1.2.3", "1.2.3-beta",
    /// trailing whitespace) by extracting the leading run of digits from each
    /// dot-separated segment. Components with no digits collapse to 0 instead
    /// of being dropped, preserving positional alignment between sides.
    private func numericVersionComponents(_ raw: String) -> [Int] {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: ".")
            .map { segment -> Int in
                let digits = segment.prefix { $0.isASCII && $0.isNumber }
                return Int(digits) ?? 0
            }
    }

    private func fallbackNotice(for error: LicenseOperationError) -> BackendFallbackNotice {
        error.fallbackNotice ?? BackendFallbackNotice(
            userMessage: error.displayMessage,
            supportCode: "LICENSE_REFRESH_FAILED",
            canRetry: true,
            preservesCachedData: true
        )
    }

    private func userFacingInstallerMessage(for error: PluginInstallerError) -> String {
        switch error {
        case .downloadFailed:
            return AppMessages.text(.installerDownloadFailed)
        case .extractionFailed:
            return AppMessages.text(.installerExtractionFailed)
        case .installationFailed:
            return AppMessages.text(.installerInstallationFailed)
        case .authenticationCancelled:
            return AppMessages.text(.installerAuthenticationCancelled)
        }
    }

    private func userFacingDownloadMessage(for error: Error) -> String {
        if let installerError = error as? PluginInstallerError {
            return userFacingInstallerMessage(for: installerError)
        }

        if let backendError = error as? AppBackendError {
            switch backendError {
            case .http(_, let payload):
                return AppMessages.backendErrorText(
                    code: payload?.code,
                    backendMessage: payload?.message,
                    default: AppMessages.text(.installerDownloadFailed)
                )
            case .transport:
                return AppMessages.text(.installerDownloadFailed)
            case .decoding:
                return AppMessages.text(.installerDownloadFailed)
            case .missingConfiguration, .invalidURL:
                return AppMessages.text(.serviceUnavailable)
            case .unknown:
                return AppMessages.text(.installerDownloadFailed)
            }
        }

        if error is URLError {
            return AppMessages.text(.installerDownloadFailed)
        }

        return AppMessages.text(.installerDownloadFailed)
    }

    private func userFacingExtractionMessage(for error: Error) -> String {
        if let installerError = error as? PluginInstallerError {
            return userFacingInstallerMessage(for: installerError)
        }

        return AppMessages.text(.installerExtractionFailed)
    }

    private func userFacingInstallationMessage(for error: Error) -> String {
        if let installerError = error as? PluginInstallerError {
            return userFacingInstallerMessage(for: installerError)
        }

        return AppMessages.text(.installerInstallationFailed)
    }

    /// Whether an SDK answer is a VERDICT (act on it) or an absence of one
    /// (fall back to the backend).
    ///
    /// `.deactivatedRemotely` belongs here and `.notActivated` does not, and
    /// that difference is exactly what this list used to hide: both arrived
    /// as `.notActivated`, so the one case where the SDK HAD reached the
    /// server and been told the seat was gone got filed under "no
    /// information", alongside every network failure.
    private func isReliableSDKStatus(_ status: LicenseValidationStatus) -> Bool {
        switch status {
        case .genuine, .genuineGracePeriod, .suspended, .revoked, .deactivatedRemotely:
            return true
        default:
            return false
        }
    }

    private func validationStatus(for backendStatus: LicenseBackendStatus) -> LicenseValidationStatus {
        switch backendStatus {
        case .active:
            return .genuine
        case .expired:
            return .expired
        case .suspended:
            return .suspended
        case .revoked:
            return .revoked
        case .notFound, .unknown:
            return .notActivated
        }
    }

    private func currentTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "dd/MM/yyyy HH:mm:ss"
        return formatter.string(from: Date())
    }
}
