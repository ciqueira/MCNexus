import Foundation

enum AppEnvironment: String, Sendable {
    case local
    case staging
    case production

    nonisolated static var current: AppEnvironment {
        #if DEBUG
        let requestedEnvironment = ProcessInfo.processInfo.environment["MCAPPSTOOLS_ENV"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if requestedEnvironment == Self.local.rawValue {
            return .local
        }
        return .staging
        #else
        return .production
        #endif
    }

    nonisolated var baseURL: String {
        switch self {
        case .local:
            return Self.requiredInfoPlistValue("MCNexusLocalBaseURL")
        case .staging:
            return Self.requiredInfoPlistValue("MCNexusStagingBaseURL")
        case .production:
            return Self.requiredInfoPlistValue("MCNexusProductionBaseURL")
        }
    }

    private nonisolated static func requiredInfoPlistValue(_ key: String) -> String {
        let rawValue = Bundle.main.object(forInfoDictionaryKey: key) as? String
        let value = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !value.isEmpty,
              !value.hasPrefix("$("),
              URL(string: value)?.scheme != nil else {
            fatalError("Missing required Info.plist value: \(key)")
        }

        return value
    }

    nonisolated var applicationSupportDirectoryName: String {
        switch self {
        case .local:
            return "MCAppsTools-Local"
        case .staging:
            return "MCAppsTools-Staging"
        case .production:
            return "MCAppsTools"
        }
    }

    nonisolated var licensesStorageKey: String {
        switch self {
        case .local:
            return "com.mcappstools.local.activeLicenses"
        case .staging:
            return "com.mcappstools.staging.activeLicenses"
        case .production:
            return "com.mcappstools.activeLicenses"
        }
    }

    nonisolated var installedBundleNameSuffix: String? {
        switch self {
        case .local:
            return "local"
        case .staging:
            return "staging"
        case .production:
            return nil
        }
    }

    nonisolated func applicationSupportDirectoryURL(fileManager: FileManager = .default) throws -> URL {
        try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        .appendingPathComponent(applicationSupportDirectoryName, isDirectory: true)
    }
}

enum AppBackendConfiguration {
    /// Backend endpoint selected by build environment. Release builds always use
    /// production; debug builds use staging unless `MCAPPSTOOLS_ENV=local` is set
    /// in the run scheme's environment variables.
    nonisolated static var baseURL: String { AppEnvironment.current.baseURL }

    /// App client version read from the bundled `VERSION` resource. Sent on
    /// every backend request via the `X-App-Version` header so the server can
    /// segment by version (analytics, future minimum-version checks).
    nonisolated static let appVersion: String = {
        guard let url = Bundle.main.url(forResource: "VERSION", withExtension: nil),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return "unknown"
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }()
}
