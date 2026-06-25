import Foundation

enum AppMessageKey: String, Sendable {
    case invalidKeyLocal
    case invalidKeyFormat
    case keyAlreadyActivated
    case productCredentialsSaveFailed
    case productAlreadyActivated
    case unexpectedError

    case validateInvalidKey
    case validateProductAlreadyActivated

    case releaseVersionNotFound
    case noReleasesAvailable
    case noOFXBundlesFound

    case downloadFailed
    case extractFailed
    case installFailed
    case deactivateFailed

    case activationRevoked
    case activationSuspended
    case activationLimitReached
    case activationInvalidKey
    case activationExpired
    case activationFailed

    case installerDownloadFailed
    case installerExtractionFailed
    case installerInstallationFailed
    case installerAuthenticationCancelled
    case installerFileNotFound

    case sdkProductConfigurationMissing
    case sdkInitFailed
    case sdkSetLicenseKeyFailed
    case sdkActivationFailed
    case sdkDeactivationFailed
    case sdkValidationFailed
    case sdkSyncFailed

    case licenseUnavailable
    case fingerprintMismatch
    case sessionInvalid
    case tooManyRequests
    case serviceUnavailable
    case releaseNotAvailable
    case releaseFileNotForPlatform
    case releaseArchived
    case downloadNotAllowed
    case licenseRefreshFailed
    case licenseRefreshTimeout
}

enum AppMessages {
    private static let messages: [AppMessageKey: String] = [
        .invalidKeyLocal: "Invalid key",
        .invalidKeyFormat: "Invalid key format. Expected XXXXXX-XXXXXX-XXXXXX-XXXXXX-XXXXXX-XXXXXXXX.",
        .keyAlreadyActivated: "Key already activated on this environment",
        .productCredentialsSaveFailed: "Could not save product credentials. Please try again.",
        .productAlreadyActivated: "This product already has an active license. Deactivate it first to use a different key.",
        .unexpectedError: "Unexpected error, please contact support",

        .validateInvalidKey: "Invalid key",
        .validateProductAlreadyActivated: "This product already has an active license. Deactivate it first to use a different key.",

        .releaseVersionNotFound: "Version %@ not found",
        .noReleasesAvailable: "No releases available",
        .noOFXBundlesFound: "No OFX bundles found in release",

        .downloadFailed: "%@",
        .extractFailed: "%@",
        .installFailed: "%@",
        .deactivateFailed: "%@",

        .activationRevoked: "This key is no longer valid.",
        .activationSuspended: "Suspended key",
        .activationLimitReached: "No activations are available for this license. Deactivate a previous machine or increase the activation limit in Cryptlex.",
        .activationInvalidKey: "Invalid key",
        .activationExpired: "License is expired",
        .activationFailed: "%@",

        .installerDownloadFailed: "Could not download the plugin. Please try again.",
        .installerExtractionFailed: "Could not prepare the plugin files. Please try again.",
        .installerInstallationFailed: "Could not install the plugin. Please try again.",
        .installerAuthenticationCancelled: "Authentication was cancelled.",
        .installerFileNotFound: "Required plugin files could not be found. Please try again.",

        .sdkProductConfigurationMissing: "License setup is unavailable for %@. Please contact support.",
        .sdkInitFailed: "Could not prepare the license on this machine. Please try again.",
        .sdkSetLicenseKeyFailed: "Could not apply this license key. Please try again.",
        .sdkActivationFailed: "Could not activate this license. Please try again.",
        .sdkDeactivationFailed: "Could not deactivate this license. Please try again.",
        .sdkValidationFailed: "Could not validate this license. Please try again.",
        .sdkSyncFailed: "Could not refresh this license. Saved license data is still being used.",

        .licenseUnavailable: "This license is not available.",
        .fingerprintMismatch: "This session does not match this machine. Please try again.",
        .sessionInvalid: "Your session is no longer valid. Please try again.",
        .tooManyRequests: "Too many requests right now. Please try again in a few minutes.",
        .serviceUnavailable: "The service is temporarily unavailable. Please try again later.",
        .releaseNotAvailable: "This release is not available.",
        .releaseFileNotForPlatform: "This release is not available for your platform.",
        .releaseArchived: "This release is no longer available.",
        .downloadNotAllowed: "Download is not allowed for this license.",
        .licenseRefreshFailed: "We could not refresh the license status. Saved license data is still being used.",
        .licenseRefreshTimeout: "The license service did not respond. Saved license data is still being used."
    ]

    static func text(_ key: AppMessageKey) -> String {
        messages[key] ?? key.rawValue
    }

    static func text(_ key: AppMessageKey, _ values: CVarArg...) -> String {
        String(format: text(key), arguments: values)
    }

    /// Resolves a user-facing message for a backend error.
    ///
    /// Priority:
    /// 1. Known `code` mapped to a local string (full control over wording and tone).
    /// 2. `backendMessage` when the code is unknown (forward-compatible for codes
    ///    the app does not yet recognize, since the backend already returns
    ///    user-friendly text per the contract).
    /// 3. The provided local `default` when neither is available.
    static func backendErrorText(
        code: String?,
        backendMessage: String?,
        default defaultText: String
    ) -> String {
        let trimmedCode = code?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let trimmedCode, !trimmedCode.isEmpty, let mapped = mappedBackendErrorKey(for: trimmedCode) {
            return text(mapped)
        }
        if let backendMessage = backendMessage?.trimmingCharacters(in: .whitespacesAndNewlines), !backendMessage.isEmpty {
            return backendMessage
        }
        return defaultText
    }

    private static func mappedBackendErrorKey(for code: String) -> AppMessageKey? {
        switch code {
        case "license_not_found":          return .activationInvalidKey
        case "license_suspended":          return .activationSuspended
        case "license_revoked":            return .activationRevoked
        case "license_expired":            return .activationExpired
        case "license_unavailable":        return .licenseUnavailable
        case "activation_limit_reached":   return .activationLimitReached
        case "fingerprint_mismatch":       return .fingerprintMismatch
        case "download_not_allowed":       return .downloadNotAllowed
        case "release_not_found":          return .releaseNotAvailable
        case "release_file_not_found":     return .releaseFileNotForPlatform
        case "release_archived":           return .releaseArchived
        case "rate_limited":               return .tooManyRequests
        case "server_error", "internal_error":
            return .serviceUnavailable
        case "unauthorized", "session_expired", "missing_token":
            return .sessionInvalid
        default:
            return nil
        }
    }
}
