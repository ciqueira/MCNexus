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
    private let releasesCache: BackendReleasesCache
    private let machineFingerprintProvider: @Sendable () -> String

    init(
        backendService: AppBackendService = AppBackendService(),
        productCredentialStore: ProductCredentialStore = ProductCredentialStore(),
        releasesCache: BackendReleasesCache = BackendReleasesCache(),
        machineFingerprintProvider: @escaping @Sendable () -> String = { MachineFingerprint.generate() }
    ) {
        self.backendService = backendService
        self.productCredentialStore = productCredentialStore
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

        #if DEBUG
        let productDataLen = productData?.count ?? 0
        Self.logger.debug("validate-installation OK productID=\(response.product.productID, privacy: .public) edition=\(response.edition, privacy: .public) activationUsage=\(response.activationUsage, privacy: .public) productDataLen=\(productDataLen, privacy: .public) releases=\(response.releases.count, privacy: .public) sessionTokenPresent=\(response.sessionToken != nil, privacy: .public)")
        #endif

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
            message: response.message?.toLicenseOperationMessage()
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
                    skipLocalActivation: result.skipLocalActivation
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
                        skipLocalActivation: nil
                    ))
                } else if firstError == nil {
                    firstError = AppBackendError.http(statusCode: 400, payload: errorDTO).asLicenseOperationError
                }
            }
        }

        if syncs.isEmpty, let firstError { return .failure(firstError) }
        return .success(syncs)
    }

    private func currentPlatformReleases(from releases: [AppBackendReleaseDTO]) -> [ReleaseInfo] {
        releases
            .map { $0.toReleaseInfo() }
            .filter(\.isCurrentPlatform)
    }

    private func applySyncBatchSideEffects(_ result: SyncBatchResultDTO) async {
        if let pd = result.product?.productData, !pd.isEmpty, let pid = result.product?.productID {
            try? productCredentialStore.saveProductData(pd, for: pid)
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
