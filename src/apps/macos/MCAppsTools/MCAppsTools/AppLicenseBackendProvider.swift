import Foundation
#if DEBUG
import OSLog
#endif

actor BackendReleasesCache {
    private var releasesByProductID: [String: [ReleaseInfo]] = [:]

    func update(_ releases: [ReleaseInfo], for productID: String) {
        releasesByProductID[productID] = releases
    }

    func releases(for productID: String) -> [ReleaseInfo] {
        releasesByProductID[productID] ?? []
    }
}

final class AppLicenseBackendProvider: LicenseBackendProvider, @unchecked Sendable {
    #if DEBUG
    private static let logger = Logger(subsystem: "MCAppsTools", category: "AppLicenseBackend")
    #endif
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

        let releases = currentPlatformReleases(from: response.releases)
        await releasesCache.update(releases, for: response.product.productID)

        if let token = response.sessionToken, let expiresIn = response.expiresIn {
            await backendService.sessionTokens.store(token: token, expiresIn: expiresIn, for: key)
        }

        return .success(LicenseBackendValidation(
            product: response.product.toAppProduct(),
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

        // Build batch payload: collect cached session tokens for each key.
        // A single batch request consumes 1 fingerprint counter unit instead
        // of N (avoids hitting the 5/min per-fingerprint rate limit when
        // managing multiple products).
        var items: [SyncBatchItemDTO] = []
        for request in requests {
            let token = await backendService.sessionTokens.token(for: request.key)
            items.append(SyncBatchItemDTO(key: request.key, sessionToken: token))
        }

        var batchResults: [SyncBatchResultDTO] = []
        do {
            var startIndex = 0
            while startIndex < items.count {
                let endIndex = min(startIndex + Self.maxSyncBatchItems, items.count)
                let batchItems = Array(items[startIndex..<endIndex])
                let batchRequest = SyncBatchRequestDTO(machineFingerprint: fingerprint, items: batchItems)
                let batchResponse = try await backendService.syncBatch(batchRequest)
                batchResults.append(contentsOf: batchResponse.results)
                startIndex = endIndex
            }
        } catch let backendError as AppBackendError {
            return .failure(backendError.asLicenseOperationError)
        } catch {
            return .failure(.local(error.localizedDescription))
        }

        let requestByKey = Dictionary(uniqueKeysWithValues: requests.map { ($0.key, $0) })
        var syncs: [LicenseBackendSync] = []
        var firstError: LicenseOperationError?

        for result in batchResults {
            if result.ok {
                await applySyncBatchSideEffects(result)
                let fallbackProduct = requestByKey[result.key]?.product
                    ?? AppProductCatalog.product(for: "")
                let product = result.product?.toAppProduct()
                    ?? fallbackProduct
                syncs.append(LicenseBackendSync(
                    key: result.key,
                    product: product,
                    status: result.status?.asLicenseBackendStatus ?? .active,
                    activationUsage: result.activationUsage ?? "--",
                    releases: result.releases.map { currentPlatformReleases(from: $0) } ?? [],
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

        if syncs.isEmpty, let firstError { return .failure(firstError) }
        return .success(syncs)
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
            try nexKeyConfigurationStore.save(entry, for: productID)
            #if DEBUG
            Self.logger.debug("Cached NexKeyRuntime configuration for productID=\(productID, privacy: .public) tenantId=\(entry.tenantId, privacy: .public) variant=\(entry.variant, privacy: .public) productDataLen=\(entry.productData.count, privacy: .public)")
            #endif
        } catch {
            // Not fatal, and deliberately not surfaced: the resolver falls
            // back to the compiled-in catalog, and the next validate/sync
            // tries again. Only a product the catalog does not cover actually
            // loses anything, and that shows up as the activation error it
            // already had before this cache existed.
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
        // Refreshed on sync, not only on install: a generation-2 tenant's
        // ProductData is derived per request, so a key rotation reaches an
        // already-installed license through here — the only call that talks
        // to the backend on a schedule. `NexKeyRuntimeProvider` notices the
        // new bytes and rebuilds its handle.
        if runtime == .nexkeyRuntimeV1, let pid = result.product?.productID {
            cacheNexKeyConfiguration(
                productID: pid,
                tenantId: result.tenantId,
                entitlements: result.entitlements,
                productData: result.product?.productData
            )
        }
        if let releases = result.releases, let pid = result.product?.productID {
            await releasesCache.update(currentPlatformReleases(from: releases), for: pid)
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
