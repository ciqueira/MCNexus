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
    case sdk(AppProduct)
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
    private let licenseProvider: LicenseProvider
    private let releaseProvider: ReleaseProvider
    private let pluginInstaller: PluginInstaller
    private let licenseStore: LicenseStore
    private let productCredentialStore: ProductCredentialStore
    private let availableProducts: [AppProduct]

    init(
        licenseBackend: LicenseBackendProvider? = nil,
        licenseProvider: LicenseProvider = LexActivatorProvider(),
        releaseProvider: ReleaseProvider? = nil,
        pluginInstaller: PluginInstaller = PluginInstaller(),
        licenseStore: LicenseStore = LicenseStore(),
        productCredentialStore: ProductCredentialStore = ProductCredentialStore(),
        availableProducts: [AppProduct] = AppProductCatalog.configuredProducts()
    ) {
        let defaultLicenseBackend = AppLicenseBackendProvider()
        self.licenseBackend = licenseBackend ?? defaultLicenseBackend
        self.licenseProvider = licenseProvider
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
            // dangling activation behind for a subsequent retry.
            if !license.skipLocalActivation {
                _ = await licenseProvider.deactivate(product: license.product)
            }

            result[index].activatedLicenseKey = nil
            result[index].availableVersion = nil
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
            let activeKey = await licenseProvider.activatedKey(for: product)
            guard activeKey == licenseKey.unsigned else {
                #if DEBUG
                Self.logger.debug("SDK poll: skipping productID=\(product.productID, privacy: .public) — activatedKey mismatch")
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
            let syncStatus = await licenseProvider.syncActivation(product: product)

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

            let syncStatus = await licenseProvider.syncActivation(product: product)
            let sdkActiveKey = await licenseProvider.activatedKey(for: product)
            let sdkOwnsThisKey = sdkActiveKey == licenseKey.unsigned
            let sdkStatus: LicenseValidationStatus?

            if sdkOwnsThisKey {
                if isReliableSDKStatus(syncStatus) {
                    sdkStatus = syncStatus
                } else {
                    let validationStatus = await licenseProvider.validate(product: product)
                    sdkStatus = isReliableSDKStatus(validationStatus) ? validationStatus : nil
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
            let resolvedStatus = sdkStatusesByKey[licenseKey]
                ?? backendSync.map { validationStatus(for: $0.status) }

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

            switch resolvedStatus {
            case .some(.genuine), .some(.genuineGracePeriod):
                let info = try? await licenseProvider.getLicenseInfo(key: licenseKey, product: product)
                if let info {
                    refreshed[index].edition = info.edition == .trial ? .trial : .full
                }
                refreshed[index].activationUsage = backendSync?.activationUsage ?? refreshed[index].activationUsage
                refreshed[index].activatedLicenseKey = licenseKey
                refreshed[index].isRevoked = false
                if refreshed[index].lifecycleState != .updateAvailable {
                    refreshed[index].lifecycleState = .active
                }

            case .some(.suspended):
                let info = try? await licenseProvider.getLicenseInfo(key: licenseKey, product: product)
                if let info {
                    refreshed[index].edition = info.edition == .trial ? .trial : .full
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
            if let productData = validation.productData {
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
                message: validation.message
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

        if activateOnMachine && !shouldSkipLocalActivation, let licenseKey {
            let activationStatus = await licenseProvider.activate(key: licenseKey, product: installProduct)
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
        if license.skipLocalActivation {
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
        case .sdk(let product):
            let status = await licenseProvider.deactivate(product: product)
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
        if hasStoredProductData(for: license.product) {
            return .sdk(license.product)
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

            if sync.skipLocalActivation == true {
                return .backendOnly(updatedUsage: sync.activationUsage)
            }

            if hasStoredProductData(for: sync.product) {
                return .sdk(sync.product)
            }

            if hasStoredProductData(for: license.product) {
                return .sdk(license.product)
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

    private func isReliableSDKStatus(_ status: LicenseValidationStatus) -> Bool {
        switch status {
        case .genuine, .genuineGracePeriod, .suspended, .revoked:
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
