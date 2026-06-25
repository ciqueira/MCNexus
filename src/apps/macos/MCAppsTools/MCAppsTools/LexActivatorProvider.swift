import Foundation
#if os(macOS)
import IOKit
#endif

final class LexActivatorProvider: LicenseProvider, @unchecked Sendable {
    private let configurationProvider: SDKProductConfigurationProviding
    private let sdkQueue = DispatchQueue(label: "com.mcappstools.lexactivator")

    init(
        configurationProvider: SDKProductConfigurationProviding = LocalSDKProductConfigurationProvider()
    ) {
        self.configurationProvider = configurationProvider
    }

    private func laCode(_ code: LexStatusCodes) -> Int32 {
        Int32(code.rawValue)
    }

    private func initializeSDK(for product: AppProduct) -> Int32 {
        guard let sdkConfiguration = configurationProvider.sdkConfiguration(for: product) else {
            return laCode(LA_FAIL)
        }

        let dataStatus = SetProductData(sdkConfiguration.productData)
        guard dataStatus == laCode(LA_OK) else {
            return dataStatus
        }

        let pidStatus = SetProductId(sdkConfiguration.productID, UInt32(LA_USER))
        guard pidStatus == laCode(LA_OK) else {
            return pidStatus
        }

        // Multiple processes (OFX plugin + this app) share the same license on disk.
        SetCacheMode(0)

        return pidStatus
    }

    private func unsupportedProductError(for product: AppProduct) -> LicenseActivationStatus {
        .error(AppMessages.text(.sdkProductConfigurationMissing, product.displayName))
    }

    // MARK: - Activate

    func activate(key: String, product: AppProduct) async -> LicenseActivationStatus {
        guard configurationProvider.sdkConfiguration(for: product) != nil else {
            return unsupportedProductError(for: product)
        }
        return await withCheckedContinuation { continuation in
            sdkQueue.async { [self] in
                continuation.resume(returning: activateSync(key: key, product: product))
            }
        }
    }

    private func activateSync(key: String, product: AppProduct) -> LicenseActivationStatus {
        guard configurationProvider.sdkConfiguration(for: product) != nil else {
            return unsupportedProductError(for: product)
        }

        let initStatus = initializeSDK(for: product)
        guard initStatus == laCode(LA_OK) else {
            return .error(AppMessages.text(.sdkInitFailed, String(initStatus)))
        }

        if isSameLicenseAlreadyActive(key: key.unsigned) {
            return .alreadyActivatedOnThisMachine
        }

        let keyStatus = SetLicenseKey(key.unsigned)
        guard keyStatus == laCode(LA_OK) else {
            if keyStatus == laCode(LA_E_LICENSE_KEY) {
                return .invalidKey
            } else {
                return .error(AppMessages.text(.sdkSetLicenseKeyFailed, String(keyStatus)))
            }
        }

        _ = SetActivationMetadata("app", "MCAppsTools")
        _ = SetActivationMetadata("hostname", ProcessInfo.processInfo.hostName)
        _ = SetActivationMetadata("machineFingerprint", machineFingerprint())

        let status = ActivateLicense()
        switch status {
        case laCode(LA_OK): return .activated
        case laCode(LA_EXPIRED): return .expired
        case laCode(LA_SUSPENDED): return .suspended
        case laCode(LA_E_REVOKED): return .revoked
        case laCode(LA_E_ACTIVATION_LIMIT): return .noActivationsLeft
        case laCode(LA_E_LICENSE_KEY): return .invalidKey
        default: return .error(AppMessages.text(.sdkActivationFailed, String(status)))
        }
    }

    private func isSameLicenseAlreadyActive(key: String) -> Bool {
        var keyBuffer = [CChar](repeating: 0, count: 256)
        guard GetLicenseKey(&keyBuffer, 256) == laCode(LA_OK) else {
            return false
        }

        let activatedKey = String(cString: keyBuffer)
        guard activatedKey == key else {
            return false
        }

        return IsLicenseGenuine() == laCode(LA_OK)
    }

    // MARK: - Deactivate

    func deactivate(product: AppProduct) async -> LicenseDeactivationStatus {
        guard configurationProvider.sdkConfiguration(for: product) != nil else {
            return .error(AppMessages.text(.sdkProductConfigurationMissing, product.displayName))
        }
        return await withCheckedContinuation { continuation in
            sdkQueue.async { [self] in
                continuation.resume(returning: deactivateSync(product: product))
            }
        }
    }

    private func deactivateSync(product: AppProduct) -> LicenseDeactivationStatus {
        guard configurationProvider.sdkConfiguration(for: product) != nil else {
            return .error(AppMessages.text(.sdkProductConfigurationMissing, product.displayName))
        }

        let initStatus = initializeSDK(for: product)
        guard initStatus == laCode(LA_OK) else {
            return .error(AppMessages.text(.sdkInitFailed, String(initStatus)))
        }

        let status = DeactivateLicense()
        switch status {
        case laCode(LA_OK): return .deactivated
        case laCode(LA_FAIL), laCode(LA_E_ACTIVATION_NOT_FOUND): return .notActivated
        default: return .error(AppMessages.text(.sdkDeactivationFailed, String(status)))
        }
    }

    // MARK: - Validate

    func validate(product: AppProduct) async -> LicenseValidationStatus {
        guard configurationProvider.sdkConfiguration(for: product) != nil else {
            return .notActivated
        }
        return await withCheckedContinuation { continuation in
            sdkQueue.async { [self] in
                continuation.resume(returning: validateSync(product: product))
            }
        }
    }

    private func validateSync(product: AppProduct) -> LicenseValidationStatus {
        guard configurationProvider.sdkConfiguration(for: product) != nil else {
            return .notActivated
        }

        let initStatus = initializeSDK(for: product)
        guard initStatus == laCode(LA_OK) else {
            return .error(AppMessages.text(.sdkInitFailed, String(initStatus)))
        }

        let status = IsLicenseGenuine()
        switch status {
        case laCode(LA_OK): return .genuine
        case laCode(LA_EXPIRED): return .expired
        case laCode(LA_SUSPENDED): return .suspended
        case laCode(LA_E_REVOKED): return .revoked
        case laCode(LA_GRACE_PERIOD_OVER): return .genuineGracePeriod
        case laCode(LA_FAIL): return .notActivated
        default: return .error(AppMessages.text(.sdkValidationFailed, String(status)))
        }
    }

    // MARK: - Sync Activation

    func syncActivation(product: AppProduct) async -> LicenseValidationStatus {
        guard configurationProvider.sdkConfiguration(for: product) != nil else {
            return .notActivated
        }
        return await withCheckedContinuation { continuation in
            sdkQueue.async { [self] in
                continuation.resume(returning: syncActivationSync(product: product))
            }
        }
    }

    private func syncActivationSync(product: AppProduct) -> LicenseValidationStatus {
        guard configurationProvider.sdkConfiguration(for: product) != nil else {
            return .notActivated
        }

        let initStatus = initializeSDK(for: product)
        guard initStatus == laCode(LA_OK) else {
            return .error(AppMessages.text(.sdkInitFailed, String(initStatus)))
        }

        let status = SyncLicenseActivation()
        switch status {
        case laCode(LA_OK): return .genuine
        case laCode(LA_EXPIRED): return .expired
        case laCode(LA_SUSPENDED): return .suspended
        case laCode(LA_E_REVOKED): return .revoked
        case laCode(LA_FAIL): return .notActivated
        default: return .error(AppMessages.text(.sdkSyncFailed, String(status)))
        }
    }

    // MARK: - License Info (SDK local data only; backend status comes via LicenseBackendProvider)

    func getLicenseInfo(key: String, product: AppProduct) async throws -> LicenseInfo? {
        await readSDKLicenseInfo(expectedKey: key, product: product)
    }

    private func readSDKLicenseInfo(expectedKey: String, product: AppProduct) async -> LicenseInfo? {
        guard configurationProvider.sdkConfiguration(for: product) != nil else {
            return nil
        }

        return await withCheckedContinuation { (continuation: CheckedContinuation<LicenseInfo?, Never>) in
            sdkQueue.async { [self] in
                let initStatus = initializeSDK(for: product)
                guard initStatus == laCode(LA_OK) else {
                    continuation.resume(returning: nil)
                    return
                }

                var keyBuffer = [CChar](repeating: 0, count: 256)
                guard GetLicenseKey(&keyBuffer, 256) == laCode(LA_OK) else {
                    continuation.resume(returning: nil)
                    return
                }
                let activatedKey = String(cString: keyBuffer)
                guard activatedKey == expectedKey.unsigned else {
                    continuation.resume(returning: nil)
                    return
                }

                var editionBuffer = [CChar](repeating: 0, count: 256)
                let editionRaw: String
                if GetLicenseMetadata("edition", &editionBuffer, 256) == laCode(LA_OK) {
                    editionRaw = String(cString: editionBuffer)
                } else {
                    editionRaw = "Full"
                }

                continuation.resume(returning: LicenseInfo(
                    edition: LicenseEditionType(fromMetadata: editionRaw)
                ))
            }
        }
    }

    // MARK: - Activated Key

    func activatedKey(for product: AppProduct) async -> String? {
        guard configurationProvider.sdkConfiguration(for: product) != nil else { return nil }

        return await withCheckedContinuation { continuation in
            sdkQueue.async { [self] in
                let initStatus = initializeSDK(for: product)
                guard initStatus == laCode(LA_OK) else {
                    continuation.resume(returning: nil)
                    return
                }

                var keyBuffer = [CChar](repeating: 0, count: 256)
                guard GetLicenseKey(&keyBuffer, 256) == laCode(LA_OK) else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: String(cString: keyBuffer))
            }
        }
    }

    // MARK: - Machine Fingerprint

    func machineFingerprint() -> String {
        MachineFingerprint.generate()
    }
}
