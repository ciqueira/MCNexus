import Foundation
#if DEBUG
import OSLog
#endif

/// KEYED BY LICENCE KEY, NEVER BY PRODUCT ID.
///
/// One OpenKey tenant serves several products under a SINGLE
/// `OPENKEY_PRODUCT_ID` — LookFilmLab's CINE / PHOTO / SCAN / GRAIN all
/// answer with the same `productID`, and only the licence's download
/// entitlement decides which assets the backend returns. Keying this cache by
/// product therefore made the four share one slot: every sync-batch item
/// overwrote it in turn, and whichever licence later read the cache got the
/// LAST item's releases. That is how a PHOTO licence on 0.1.3 came to be
/// offered CINE's 0.2.3 — an update that does not exist for it, and one the
/// backend never sent, since it filters per entitlement correctly.
///
/// The licence key is the only identifier the app holds that is unique per
/// product here, so it is the key.
actor BackendReleasesCache {
    private var releasesByLicenseKey: [String: [ReleaseInfo]] = [:]

    func update(_ releases: [ReleaseInfo], for licenseKey: String) {
        releasesByLicenseKey[licenseKey] = releases
    }

    func releases(for licenseKey: String) -> [ReleaseInfo] {
        releasesByLicenseKey[licenseKey] ?? []
    }
}

final class AppLicenseBackendProvider: LicenseBackendProvider, @unchecked Sendable {
    #if DEBUG
    private static let logger = Logger(subsystem: "MCAppsTools", category: "AppLicenseBackend")
    #endif
    // Cloudflare Workers has a hard ceiling of 50 subrequests per invocation.
    // Each license in OpenKey/Neon makes ~2-3 DB subrequests. Chunking by 10 items
    // guarantees a batch stays comfortably under the 50-subrequest limit.
    private static let maxSyncBatchItems = 10

    private let backendService: AppBackendService
    private let productCredentialStore: ProductCredentialStore
    private let nexKeyConfigurationStore: NexKeyRuntimeConfigurationStore
    private let releasesCache: BackendReleasesCache
    private let machineFingerprintProvider: @Sendable () -> String

    init(
        backendService: AppBackendService = AppBackendService(),
        productCredentialStore: ProductCredentialStore = ProductCredentialStore(),
        nexKeyConfigurationStore: NexKeyRuntimeConfigurationStore = NexKeyRuntimeConfigurationStore(),
        releasesCache: BackendReleasesCache = BackendReleasesCache(),
        machineFingerprintProvider: @escaping @Sendable () -> String = { MachineFingerprint.generate() }
    ) {
        self.backendService = backendService
        self.productCredentialStore = productCredentialStore
        self.nexKeyConfigurationStore = nexKeyConfigurationStore
        self.releasesCache = releasesCache
        self.machineFingerprintProvider = machineFingerprintProvider
    }

    var sharedReleasesCache: BackendReleasesCache { releasesCache }
    var sharedBackendService: AppBackendService { backendService }

    func validateInstallationLicense(
        key: String,
        activateOnMachine: Bool
    ) async -> Result<LicenseBackendValidation, LicenseOperationError> {
        let request = ValidateInstallationRequestDTO(
            key: key,
            machineFingerprint: machineFingerprintProvider(),
            activateOnMachine: activateOnMachine
        )

        let response: ValidateInstallationResponseDTO
        do {
            response = try await backendService.validateInstallation(request)
        } catch let backendError as AppBackendError {
            return .failure(backendError.asLicenseOperationError)
        } catch {
            return .failure(.local(error.localizedDescription))
        }

        let productData = response.product.productData
        let runtime = response.licensing?.asLicenseRuntime ?? .cryptlexLexActivatorV1

        #if DEBUG
        let productDataLen = productData?.count ?? 0
        Self.logger.debug("validate-installation OK productID=\(response.product.productID, privacy: .public) runtime=\(runtime.wireValue, privacy: .public) edition=\(response.edition, privacy: .public) activationUsage=\(response.activationUsage, privacy: .public) productDataLen=\(productDataLen, privacy: .public) releases=\(response.releases.count, privacy: .public) sessionTokenPresent=\(response.sessionToken != nil, privacy: .public)")
        #endif

        // ONE STORE PER RUNTIME, and the branch below decides which.
        // `productCredentialStore` feeds Cryptlex's `SetProductData()` and a
        // NexKey-shaped blob there would be rejected as malformed — worse, its
        // non-emptiness is read as "this license has a local Cryptlex
        // activation" when routing a deactivation
        // (`LicenseWorkflowCoordinator.hasStoredProductData`), so a NexKey blob
        // in it would send a deactivation to the SDK that cannot release the
        // seat. `nexKeyConfigurationStore` is the NexKey side of the same idea.
        if runtime == .cryptlexLexActivatorV1 {
            if let productData, !productData.isEmpty {
                do {
                    try productCredentialStore.saveProductData(productData, for: response.product.productID)
                    #if DEBUG
                    Self.logger.debug("Saved productData to local encrypted storage for productID=\(response.product.productID, privacy: .public)")
                    #endif
                } catch {
                    #if DEBUG
                    Self.logger.error("Failed to save productData: \(String(describing: error), privacy: .public)")
                    #endif
                    return .failure(.local(AppMessages.text(.productCredentialsSaveFailed)))
                }
            } else {
                #if DEBUG
                Self.logger.error("validate-installation response had NO productData — SDK activation will fail for productID=\(response.product.productID, privacy: .public)")
                #endif
            }
        } else if runtime == .nexkeyRuntimeV1 {
            cacheNexKeyConfiguration(
                productID: response.product.productID,
                tenantId: response.tenantId,
                entitlements: response.entitlements,
                productData: productData
            )
        }

        let rawReleases = currentPlatformReleases(from: response.releases)
        let allowBeta = response.edition.asLicenseEdition == .beta
        let releases = allowBeta ? rawReleases : rawReleases.filter { $0.channel.lowercased() != "beta" }
        await releasesCache.update(releases, for: key)

        if let token = response.sessionToken, let expiresIn = response.expiresIn {
            await backendService.sessionTokens.store(token: token, expiresIn: expiresIn, for: key)
        }

        let variant = Self.variant(from: response.entitlements)
        return .success(LicenseBackendValidation(
            product: response.product.toAppProduct(variant: variant),
            edition: response.edition.asLicenseEdition,
            skipLocalActivation: response.skipLocalActivation ?? false,
            activationUsage: response.activationUsage,
            productData: productData,
            releases: releases,
            message: response.message?.toLicenseOperationMessage(),
            runtime: response.licensing?.asLicenseRuntime ?? .cryptlexLexActivatorV1,
            tenantId: response.tenantId
        ))
    }

    func syncLicenses(_ requests: [LicenseBackendSyncRequest]) async -> Result<[LicenseBackendSync], LicenseOperationError> {
        guard !requests.isEmpty else { return .success([]) }

        let fingerprint = machineFingerprintProvider()

        var items: [SyncBatchItemDTO] = []
        for request in requests {
            // Fase 3: If the license is already managed by NexKeyRuntime SDK locally,
            // skip adding it to sync-batch. It will be refreshed via releases/check!
            if request.runtime == .nexkeyRuntimeV1 && request.hasLocalSDKActivation {
                continue
            }
            let token = await backendService.sessionTokens.token(for: request.key)
            items.append(SyncBatchItemDTO(key: request.key, sessionToken: token))
        }

        // Build releases check payload (Fase 2)
        let checkItems = requests.map {
            ReleasesCheckItemDTO(
                key: $0.key,
                tenantId: $0.tenantId,
                installedVersion: $0.installedVersion,
                productName: $0.product.name,
                edition: $0.edition
            )
        }
        let checkRequest = ReleasesCheckRequestDTO(platform: "macos", items: checkItems)

        // Run releases check concurrently with sync-batch
        async let checkResponseTask: ReleasesCheckResponseDTO? = {
            do {
                return try await self.backendService.checkReleases(checkRequest)
            } catch {
                #if DEBUG
                Self.logger.warning("releases/check request failed, falling back to cached releases: \(error.localizedDescription, privacy: .public)")
                #endif
                return nil
            }
        }()

        var batchResults: [SyncBatchResultDTO] = []
        var batchError: LicenseOperationError?
        var startIndex = 0
        while startIndex < items.count {
            let endIndex = min(startIndex + Self.maxSyncBatchItems, items.count)
            let batchItems = Array(items[startIndex..<endIndex])
            let batchRequest = SyncBatchRequestDTO(
                machineFingerprint: fingerprint,
                items: batchItems,
                omitReleases: true
            )
            do {
                let batchResponse = try await backendService.syncBatch(batchRequest)
                batchResults.append(contentsOf: batchResponse.results)
            } catch let backendError as AppBackendError {
                batchError = backendError.asLicenseOperationError
                break
            } catch {
                batchError = .local(error.localizedDescription)
                break
            }
            startIndex = endIndex
        }

        if !items.isEmpty, batchResults.isEmpty, let batchError {
            return .failure(batchError)
        }

        let releasesCheck = await checkResponseTask
        let requestByKey = Dictionary(uniqueKeysWithValues: requests.map { ($0.key, $0) })
        var syncs: [LicenseBackendSync] = []
        var firstError: LicenseOperationError? = batchError

        for result in batchResults {
            if result.ok {
                let fallbackProduct = requestByKey[result.key]?.product
                    ?? AppProductCatalog.product(for: "")
                let product = result.product?.toAppProduct(variant: Self.variant(from: result.entitlements))
                    ?? fallbackProduct
                await applySyncBatchSideEffects(result)

                let resolvedEdition = result.edition?.asLicenseEdition
                    ?? requestByKey[result.key]?.edition?.asLicenseEdition
                let allowBeta = resolvedEdition == .beta

                // Resolve releases: from releases/check catalog first, or direct batch releases if present, or cache
                let catalogReleases = resolveCatalogReleases(
                    tenantId: result.tenantId,
                    productName: product.name,
                    entitlements: result.entitlements,
                    directReleases: result.releases,
                    releasesCheck: releasesCheck,
                    allowBeta: allowBeta
                )

                let resolvedReleases: [ReleaseInfo]
                if !catalogReleases.isEmpty {
                    resolvedReleases = catalogReleases
                    await releasesCache.update(resolvedReleases, for: result.key)
                } else if let directReleases = result.releases, !directReleases.isEmpty {
                    resolvedReleases = currentPlatformReleases(from: directReleases)
                    await releasesCache.update(resolvedReleases, for: result.key)
                } else {
                    resolvedReleases = await releasesCache.releases(for: result.key)
                }

                syncs.append(LicenseBackendSync(
                    key: result.key,
                    product: product,
                    status: result.status?.asLicenseBackendStatus ?? .active,
                    edition: result.edition?.asLicenseEdition,
                    activationUsage: result.activationUsage ?? "--",
                    releases: resolvedReleases,
                    skipLocalActivation: result.skipLocalActivation,
                    runtime: result.licensing?.asLicenseRuntime ?? .cryptlexLexActivatorV1,
                    tenantId: result.tenantId,
                    activation: MachineActivationState(wireValue: result.activation)
                ))
            } else if let errorDTO = result.error {
                let domainStatus: LicenseBackendStatus? = switch errorDTO.code.lowercased() {
                case "license_not_found": .notFound
                case "license_suspended": .suspended
                case "license_revoked": .revoked
                case "license_expired", "license_unavailable": .expired
                default: nil
                }
                if let domainStatus, let req = requestByKey[result.key] {
                    syncs.append(LicenseBackendSync(
                        key: result.key,
                        product: req.product,
                        status: domainStatus,
                        // A failed item carries no edition — see
                        // `LicenseBackendSync.edition`.
                        edition: nil,
                        activationUsage: "--",
                        releases: [],
                        skipLocalActivation: nil,
                        runtime: .cryptlexLexActivatorV1,
                        tenantId: nil,
                        // A failed item carries a verdict about the LICENCE
                        // (revoked, suspended, gone). It says nothing about
                        // the seat, and inventing an answer here would let a
                        // licence-level failure masquerade as a deactivation.
                        activation: .unknown
                    ))
                } else if firstError == nil {
                    firstError = AppBackendError.http(statusCode: 400, payload: errorDTO).asLicenseOperationError
                }
            }
        }

        // Synthesize sync results for NexKeyRuntime-routed requests that are already handled by local SDK and were not in the batch.
        // Their releases are resolved from releases/check catalog directly.
        let processedKeys = Set(syncs.map { $0.key })
        let sdkRequests = requests.filter { !processedKeys.contains($0.key) && $0.runtime == .nexkeyRuntimeV1 && $0.hasLocalSDKActivation }
        for req in sdkRequests {
            let allowBeta = req.edition?.asLicenseEdition == .beta
            let catalogReleases = resolveCatalogReleases(
                tenantId: req.tenantId,
                productName: req.product.name,
                entitlements: nil,
                directReleases: nil,
                releasesCheck: releasesCheck,
                allowBeta: allowBeta
            )
            let resolvedReleases: [ReleaseInfo]
            if !catalogReleases.isEmpty {
                resolvedReleases = catalogReleases
                await releasesCache.update(resolvedReleases, for: req.key)
            } else {
                resolvedReleases = await releasesCache.releases(for: req.key)
            }

            syncs.append(LicenseBackendSync(
                key: req.key,
                product: req.product,
                status: .active,
                edition: req.edition?.asLicenseEdition,
                activationUsage: "--",
                releases: resolvedReleases,
                skipLocalActivation: true,
                runtime: .nexkeyRuntimeV1,
                tenantId: req.tenantId,
                activation: .active
            ))
        }

        if syncs.isEmpty, let firstError { return .failure(firstError) }
        return .success(syncs)
    }

    private func resolveCatalogReleases(
        tenantId: String?,
        productName: String,
        entitlements: [String]?,
        directReleases: [AppBackendReleaseDTO]?,
        releasesCheck: ReleasesCheckResponseDTO?,
        allowBeta: Bool = false
    ) -> [ReleaseInfo] {
        let rawReleases: [ReleaseInfo]
        if let tenantId, let catalog = releasesCheck?.catalogs[tenantId] {
            let targetProductName = productName.trimmingCharacters(in: .whitespacesAndNewlines)
            let targetSlug = targetProductName.lowercased().filter { $0.isLetter || $0.isNumber }

            let matchingDTOs = catalog.releases.filter { release in
                guard !targetSlug.isEmpty else { return true }

                // 1. Check requiredEntitlements if present
                if let required = release.requiredEntitlements, !required.isEmpty,
                   let owned = entitlements, !owned.isEmpty {
                    let ownedSet = Set(owned.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) })
                    let match = required.contains { ownedSet.contains($0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)) }
                    if match { return true }
                }

                // 2. Check displayName
                if let displayName = release.displayName {
                    let normDisp = displayName.lowercased().filter { $0.isLetter || $0.isNumber }
                    if normDisp == targetSlug || targetSlug.contains(normDisp) || normDisp.contains(targetSlug) {
                        return true
                    }
                }

                // 3. Check name
                let normName = release.name.lowercased().filter { $0.isLetter || $0.isNumber }
                if normName.contains(targetSlug) || targetSlug.contains(normName) {
                    return true
                }

                return false
            }

            let releasesToMap = matchingDTOs.isEmpty ? catalog.releases : matchingDTOs
            rawReleases = releasesToMap.map { $0.toReleaseInfo() }.filter(\.isCurrentPlatform)
        } else if let directReleases, !directReleases.isEmpty {
            rawReleases = currentPlatformReleases(from: directReleases)
        } else {
            rawReleases = []
        }

        if allowBeta {
            return rawReleases
        } else {
            return rawReleases.filter { $0.channel.lowercased() != "beta" }
        }
    }

    /// Caches what `NexKeyRuntimeProvider` needs before `activate()`:
    /// the derived ProductData blob, the tenant, and the entitlement the SDK
    /// calls the `variant`.
    ///
    /// WRITES ONLY A COMPLETE TRIPLE, and never clears on an incomplete one.
    /// A backend that cannot derive the blob answers `productData: null`
    /// rather than failing the request (appClient's `resolveOpenKeyProductData`
    /// degrades on purpose, so basic license validation survives a broken
    /// keyset). Overwriting a good cached entry with that would take a working
    /// install offline because one response could not answer; keeping the last
    /// known-good triple is strictly better, and the next healthy response
    /// replaces it.
    private func cacheNexKeyConfiguration(
        productID: String,
        tenantId: String?,
        entitlements: [String]?,
        productData: String?
    ) {
        guard let tenantId = tenantId?.trimmingCharacters(in: .whitespacesAndNewlines), !tenantId.isEmpty,
              let productData = productData?.trimmingCharacters(in: .whitespacesAndNewlines), !productData.isEmpty else {
            #if DEBUG
            Self.logger.error("NexKeyRuntime-routed response was missing tenantId or productData — keeping any cached configuration for productID=\(productID, privacy: .public)")
            #endif
            return
        }

        let entry = NexKeyProductDataEntry(
            tenantId: tenantId,
            variant: Self.variant(from: entitlements),
            productData: productData
        )
        do {
            try nexKeyConfigurationStore.save(entry, for: productID, variant: entry.variant)
            #if DEBUG
            Self.logger.debug("Cached NexKeyRuntime configuration for productID=\(productID, privacy: .public) tenantId=\(entry.tenantId, privacy: .public) variant=\(entry.variant, privacy: .public) productDataLen=\(entry.productData.count, privacy: .public)")
            #endif
        } catch {
            #if DEBUG
            Self.logger.error("Failed to cache NexKeyRuntime configuration for productID=\(productID, privacy: .public): \(String(describing: error), privacy: .public)")
            #endif
        }
    }

    /// The SDK takes ONE variant and the backend guarantees exactly one
    /// download entitlement per OpenKey license
    /// (`normalizeSingleDownloadEntitlement`), so first-non-empty is the whole
    /// rule. The default matches the backend's own
    /// `DEFAULT_DOWNLOAD_ENTITLEMENT` and covers a response too old to carry
    /// the field.
    private static func variant(from entitlements: [String]?) -> String {
        entitlements?
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })
            ?? "download:default"
    }

    private func currentPlatformReleases(from releases: [AppBackendReleaseDTO]) -> [ReleaseInfo] {
        releases
            .map { $0.toReleaseInfo() }
            .filter(\.isCurrentPlatform)
    }

    private func applySyncBatchSideEffects(_ result: SyncBatchResultDTO) async {
        let runtime = result.licensing?.asLicenseRuntime ?? .cryptlexLexActivatorV1
        if runtime == .cryptlexLexActivatorV1,
           let pd = result.product?.productData, !pd.isEmpty, let pid = result.product?.productID {
            try? productCredentialStore.saveProductData(pd, for: pid)
        }
        if runtime == .nexkeyRuntimeV1, let pid = result.product?.productID {
            cacheNexKeyConfiguration(
                productID: pid,
                tenantId: result.tenantId,
                entitlements: result.entitlements,
                productData: result.product?.productData
            )
        }
        if let releases = result.releases {
            await releasesCache.update(currentPlatformReleases(from: releases), for: result.key)
        }
        if let token = result.sessionToken, let expiresIn = result.expiresIn {
            await backendService.sessionTokens.store(token: token, expiresIn: expiresIn, for: result.key)
        }
    }

    func refreshLicenseStatus(
        key: String,
        product: AppProduct
    ) async -> LicenseBackendStatus {
        let request = LicenseBackendSyncRequest(key: key, product: product)
        switch await syncLicenses([request]) {
        case .success(let syncs):
            return syncs.first?.status ?? .unknown
        case .failure:
            return .unknown
        }
    }

    func activationUsage(for key: String) async -> String {
        let product = AppProductCatalog.product(for: "")
        let request = LicenseBackendSyncRequest(key: key, product: product)
        switch await syncLicenses([request]) {
        case .success(let syncs):
            return syncs.first?.activationUsage ?? "--"
        case .failure:
            return "--"
        }
    }

    func product(for product: AppProduct) async -> AppProduct {
        product
    }

    func migrateBinding(key: String) async {
        guard let sessionToken = await backendService.sessionTokens.token(for: key), !sessionToken.isEmpty else {
            #if DEBUG
            Self.logger.debug("migrate-binding skipped — no session token cached for this key")
            #endif
            return
        }
        do {
            let response = try await backendService.migrateBinding(sessionToken: sessionToken)
            #if DEBUG
            Self.logger.debug("migrate-binding outcome=\(response.outcome, privacy: .public) activationId=\(response.activationId ?? "nil", privacy: .public)")
            #endif
        } catch {
            #if DEBUG
            Self.logger.debug("migrate-binding failed (non-fatal — proceeding to SDK activate regardless): \(String(describing: error), privacy: .public)")
            #endif
        }
    }

    func warmUp() async {
        do {
            let response = try await backendService.checkHealth()
            #if DEBUG
            Self.logger.debug("backend health OK status=\(response.status, privacy: .public) version=\(response.version ?? "-", privacy: .public)")
            #endif
        } catch {
            #if DEBUG
            Self.logger.debug("backend health check failed (non-fatal): \(String(describing: error), privacy: .public)")
            #endif
        }
    }

    func fetchLatestApp() async -> AppLatestInfo? {
        do {
            let response = try await backendService.fetchLatestApp()
            guard let downloadURL = URL(string: response.downloadURL) else {
                #if DEBUG
                Self.logger.debug("app/latest invalid downloadURL=\(response.downloadURL, privacy: .public)")
                #endif
                return nil
            }
            return AppLatestInfo(version: response.version, downloadURL: downloadURL)
        } catch {
            #if DEBUG
            Self.logger.debug("app/latest fetch failed (non-fatal): \(String(describing: error), privacy: .public)")
            #endif
            return nil
        }
    }
}
