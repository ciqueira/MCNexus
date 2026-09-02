import CryptoKit
import Foundation
#if DEBUG
import OSLog
#endif

enum AppBackendError: Error, Sendable {
    case missingConfiguration(String)
    case invalidURL
    case http(statusCode: Int, payload: AppBackendErrorDTO?)
    case decoding(String)
    case transport(URLError)
    case unknown(Error)
}

/// Per-endpoint network policy. Timeouts are tuned for each call's UX
/// constraints (e.g. sync is a background heartbeat → fail fast; validate is
/// blocking → tolerate cold starts). Retries cover transient failures
/// (Render cold start, brief connectivity blips, 5xx) without surfacing them
/// to the user.
struct AppBackendEndpointConfig: Sendable {
    let timeout: TimeInterval
    let maxAttempts: Int
    let initialBackoff: TimeInterval

    static let validate = AppBackendEndpointConfig(timeout: 25, maxAttempts: 2, initialBackoff: 1.5)
    static let sync = AppBackendEndpointConfig(timeout: 15, maxAttempts: 2, initialBackoff: 1.0)
    static let resolveDownload = AppBackendEndpointConfig(timeout: 20, maxAttempts: 2, initialBackoff: 1.0)
    /// Health check is a wake-up ping for the Render container. Single
    /// attempt, short timeout — failure is non-fatal (refresh has its own
    /// retry logic). Keeping the budget tight so the launch flow is not
    /// blocked even when the backend is unreachable.
    static let health = AppBackendEndpointConfig(timeout: 10, maxAttempts: 1, initialBackoff: 0)
    /// Batch carries validate fallback internally per-item → same budget as validate.
    static let syncBatch = AppBackendEndpointConfig(timeout: 25, maxAttempts: 2, initialBackoff: 1.5)
    /// App update check. Fail fast and silent: the banner is non-essential, so
    /// short timeout and no retries keep the launch flow snappy when the
    /// endpoint is slow or unreachable.
    static let appLatest = AppBackendEndpointConfig(timeout: 8, maxAttempts: 1, initialBackoff: 0)
}

nonisolated struct SessionTokenEntry: Codable, Sendable {
    let token: String
    let expiresAt: Date
}

actor SessionTokenStore {
    private static let storageDirectoryComponents = ["State", "Cache"]
    private static let keyDerivationSalt = "MCAppsTools.SessionTokenStore.v1"
    private static let staleCacheAge: TimeInterval = 24 * 60 * 60

    /// Safety margin applied to `expiresAt` so callers renew before the JWT
    /// actually expires server-side. Mitigates clock skew and request latency.
    /// A token with less than `renewalSafetyBuffer` of life left is treated
    /// as already expired, triggering proactive renewal.
    private let renewalSafetyBuffer: TimeInterval
    private let fileManager: FileManager
    private let machineFingerprintProvider: @Sendable () -> String

    private var tokensByKey: [String: SessionTokenEntry] = [:]

    init(
        renewalSafetyBuffer: TimeInterval = 60,
        fileManager: FileManager = .default,
        machineFingerprintProvider: @escaping @Sendable () -> String = { MachineFingerprint.generate() }
    ) {
        self.renewalSafetyBuffer = renewalSafetyBuffer
        self.fileManager = fileManager
        self.machineFingerprintProvider = machineFingerprintProvider
    }

    func store(token: String, expiresIn: Int, for licenseKey: String) {
        cleanupStaleCacheFiles()

        let expiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))
        let entry = SessionTokenEntry(token: token, expiresAt: expiresAt)
        tokensByKey[licenseKey] = entry
        try? writeToLocalStorage(entry, for: licenseKey)
    }

    /// Returns the JWT if it still has more than `renewalSafetyBuffer` seconds
    /// of life left. Tokens are persisted locally to avoid unnecessary
    /// validate-installation fallbacks after relaunch, but expired tokens are
    /// deleted before use.
    func token(for licenseKey: String) -> String? {
        cleanupStaleCacheFiles()

        guard let entry = tokensByKey[licenseKey] ?? readFromLocalStorage(for: licenseKey) else {
            return nil
        }

        let renewalThreshold = Date().addingTimeInterval(renewalSafetyBuffer)
        if entry.expiresAt <= renewalThreshold {
            tokensByKey[licenseKey] = nil
            try? deleteFromLocalStorage(for: licenseKey)
            return nil
        }

        tokensByKey[licenseKey] = entry
        return entry.token
    }

    func clear(for licenseKey: String) {
        tokensByKey[licenseKey] = nil
        try? deleteFromLocalStorage(for: licenseKey)
    }

    private func writeToLocalStorage(_ entry: SessionTokenEntry, for licenseKey: String) throws {
        let data = try JSONEncoder().encode(entry)
        let sealedBox = try AES.GCM.seal(data, using: encryptionKey(for: licenseKey))
        guard let encryptedData = sealedBox.combined else { return }

        let directoryURL = try storageDirectoryURL()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try encryptedData.write(to: tokenURL(for: licenseKey, in: directoryURL), options: .atomic)
    }

    private func readFromLocalStorage(for licenseKey: String) -> SessionTokenEntry? {
        do {
            let fileURL = tokenURL(for: licenseKey, in: try storageDirectoryURL())
            guard fileManager.fileExists(atPath: fileURL.path) else { return nil }

            let encryptedData = try Data(contentsOf: fileURL)
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: encryptionKey(for: licenseKey))
            return try JSONDecoder().decode(SessionTokenEntry.self, from: decryptedData)
        } catch {
            try? deleteFromLocalStorage(for: licenseKey)
            return nil
        }
    }

    private func deleteFromLocalStorage(for licenseKey: String) throws {
        let fileURL = tokenURL(for: licenseKey, in: try storageDirectoryURL())
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        try fileManager.removeItem(at: fileURL)
    }

    private func cleanupStaleCacheFiles(now: Date = Date()) {
        do {
            let directoryURL = try storageDirectoryURL()
            guard fileManager.fileExists(atPath: directoryURL.path) else { return }

            let fileURLs = try fileManager.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            )

            for fileURL in fileURLs {
                let values = try fileURL.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey])
                guard values.isRegularFile == true else { continue }

                let isCacheFile = fileURL.pathExtension == "cache"
                let modifiedAt = values.contentModificationDate ?? .distantPast
                let isStale = now.timeIntervalSince(modifiedAt) > Self.staleCacheAge

                if !isCacheFile || isStale {
                    try? fileManager.removeItem(at: fileURL)
                }
            }
        } catch {
            return
        }
    }

    private func storageDirectoryURL() throws -> URL {
        var url = try AppEnvironment.current.applicationSupportDirectoryURL(fileManager: fileManager)

        for component in Self.storageDirectoryComponents {
            url.appendPathComponent(component, isDirectory: true)
        }
        return url
    }

    private func tokenURL(for licenseKey: String, in directoryURL: URL) -> URL {
        directoryURL.appendingPathComponent(fileName(for: licenseKey), isDirectory: false)
    }

    private func fileName(for licenseKey: String) -> String {
        let digest = SHA256.hash(data: Data(licenseKey.utf8))
        return digest.map { String(format: "%02x", $0) }.joined() + ".cache"
    }

    private func encryptionKey(for licenseKey: String) -> SymmetricKey {
        var material = Data()
        material.append(Data(Self.keyDerivationSalt.utf8))
        material.append(Data((Bundle.main.bundleIdentifier ?? "com.mcappstools.app").utf8))
        material.append(Data(machineFingerprintProvider().utf8))
        material.append(Data(licenseKey.utf8))
        let digest = SHA256.hash(data: material)
        return SymmetricKey(data: digest)
    }
}

actor AppBackendService {
    #if DEBUG
    private static let logger = Logger(subsystem: "MCAppsTools", category: "AppBackend")
    #endif

    private let urlSession: URLSession
    let sessionTokens: SessionTokenStore

    /// When the backend responds with 429 we honour the `Retry-After` header
    /// and short-circuit every subsequent request until this instant. Avoids
    /// pounding the API right after a rate-limit hit and keeps the contadores
    /// on the server from staying perpetually saturated.
    private var rateLimitedUntil: Date?

    init(
        urlSession: URLSession = .shared,
        sessionTokens: SessionTokenStore = SessionTokenStore()
    ) {
        self.urlSession = urlSession
        self.sessionTokens = sessionTokens
    }

    /// Wakes up the Render container ahead of any authenticated call. Fire
    /// and forget on the caller side — failures are non-fatal because the
    /// regular endpoints have their own retry/timeout policies.
    func checkHealth() async throws -> HealthResponseDTO {
        try await get(path: "/v1/health", config: .health)
    }

    /// Lightweight client-update check. Anonymous (no Authorization) and best
    /// effort: errors surface as thrown `AppBackendError` so callers can fail
    /// silently without polluting the UI.
    func fetchLatestApp(platform: String = "macos") async throws -> AppLatestResponseDTO {
        try await get(
            path: "/v1/app/latest",
            config: .appLatest,
            queryItems: [URLQueryItem(name: "platform", value: platform)]
        )
    }

    func validateInstallation(
        _ request: ValidateInstallationRequestDTO
    ) async throws -> ValidateInstallationResponseDTO {
        try await post(
            path: "/v1/licenses/validate-installation",
            body: request,
            sessionToken: nil,
            config: .validate
        )
    }

    func syncLicense(
        _ request: SyncLicenseRequestDTO,
        sessionToken: String?
    ) async throws -> SyncLicenseResponseDTO {
        try await post(
            path: "/v1/licenses/sync",
            body: request,
            sessionToken: sessionToken,
            config: .sync
        )
    }

    /// Fase 5 / D42 — renames this machine's activation from the legacy
    /// identity to the one the SDK computes, in place. Authenticated by the
    /// session JWT (never a fingerprint in the body): the token was issued
    /// by validate-installation against a specific machine, so identity
    /// comes from the session, not from whatever the caller claims.
    func migrateBinding(sessionToken: String) async throws -> MigrateBindingResponseDTO {
        try await post(
            path: "/v1/licenses/migrate-binding",
            body: MigrateBindingRequestDTO(hardwareId: nil),
            sessionToken: sessionToken,
            config: .validate
        )
    }

    /// Aggregated heartbeat — replaces N parallel sync calls with a single
    /// request. The endpoint is anonymous (no Authorization header); each item
    /// carries its own sessionToken in the body. The server handles per-item
    /// fallback to validate-installation internally, keeping fingerprint
    /// counter at 1 unit instead of N.
    func syncBatch(_ request: SyncBatchRequestDTO) async throws -> SyncBatchResponseDTO {
        try await post(
            path: "/v1/licenses/sync-batch",
            body: request,
            sessionToken: nil,
            config: .syncBatch
        )
    }

    func resolveDownload(
        releaseId: String,
        request: ResolveDownloadRequestDTO,
        sessionToken: String?
    ) async throws -> ResolveDownloadResponseDTO {
        let response: ResolveDownloadResponseDTO = try await post(
            path: "/v1/releases/\(releaseId)/resolve-download",
            body: request,
            sessionToken: sessionToken,
            config: .resolveDownload
        )
        #if DEBUG
        Self.logger.debug("resolve-download response: name=\(response.name, privacy: .public) url=\(response.url, privacy: .private) expiresAt=\(response.expiresAt ?? "-", privacy: .public) fileSize=\(response.fileSize.map(String.init) ?? "nil", privacy: .public)")
        #endif
        return response
    }

    func downloadFile(
        from urlString: String,
        suggestedName: String,
        knownFileSize: Int64? = nil,
        progress: @escaping @Sendable (_ fraction: Double, _ bytesWritten: Int64, _ bytesTotal: Int64) -> Void
    ) async throws -> URL {
        guard let url = Self.resolveDownloadURL(urlString) else {
            #if DEBUG
            Self.logger.error("downloadFile: invalid URL string=\(urlString, privacy: .private)")
            #endif
            throw AppBackendError.invalidURL
        }

        #if DEBUG
        Self.logger.debug("downloadFile starting GET \(url.absoluteString, privacy: .private)")
        #endif

        let destDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MCAppsTools", isDirectory: true)
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
        let destURL = destDir.appendingPathComponent(sanitizedDownloadFileName(suggestedName))
        #if DEBUG
        print("[Download] destination=\(destURL.path) suggestedName=\(suggestedName) knownFileSize=\(knownFileSize ?? -1)")
        #endif

        let delegate = AppBackendDownloadDelegate(destinationURL: destURL, knownFileSize: knownFileSize, onProgress: progress)
        let downloadSession = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)

        return try await withCheckedThrowingContinuation { continuation in
            delegate.setContinuation(continuation)
            downloadSession.downloadTask(with: url).resume()
        }
    }

    // MARK: - HTTP core

    private func post<Body: Encodable, Response: Decodable>(
        path: String,
        body: Body,
        sessionToken: String?,
        config: AppBackendEndpointConfig
    ) async throws -> Response {
        var request = try buildRequest(path: path, method: "POST", sessionToken: sessionToken, config: config)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        return try await sendWithRetry(request, path: path, config: config)
    }

    private func get<Response: Decodable>(
        path: String,
        config: AppBackendEndpointConfig,
        queryItems: [URLQueryItem]? = nil
    ) async throws -> Response {
        let request = try buildRequest(
            path: path,
            method: "GET",
            sessionToken: nil,
            config: config,
            queryItems: queryItems
        )
        return try await sendWithRetry(request, path: path, config: config)
    }

    private func buildRequest(
        path: String,
        method: String,
        sessionToken: String?,
        config: AppBackendEndpointConfig,
        queryItems: [URLQueryItem]? = nil
    ) throws -> URLRequest {
        guard var components = URLComponents(string: AppBackendConfiguration.baseURL.appending(path)) else {
            throw AppBackendError.invalidURL
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            throw AppBackendError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = config.timeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(AppBackendConfiguration.appVersion, forHTTPHeaderField: "X-App-Version")
        // Declares this build has NexKeyRuntimeProvider — the discriminator
        // that lets a Fase-5-flagged tenant route to the SDK (D41) instead of
        // treating this as an old app. Every endpoint goes through this one
        // choke point, which is why this is a one-line change rather than
        // one per route (§3.9 / P34).
        request.setValue("nexkeyruntime-sdk", forHTTPHeaderField: "X-NexKey-Capabilities")
        // Lets the server decide whether it can derive this machine's SDK
        // identity from the fingerprint we already send. On macOS it can —
        // both sides read IOPlatformUUID — so a seat lookup that finds
        // nothing really does mean the seat is gone. A client that stays
        // silent (the Windows app today) gets "unknown" instead, and the
        // server declines to guess. Same choke point as the header above.
        request.setValue("macos", forHTTPHeaderField: "X-NexKey-Platform")

        if let sessionToken, !sessionToken.isEmpty {
            request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    /// Backend `resolve-download` may return either an absolute URL (legacy /
    /// external storage) or a path-only string like `/v1/download?token=...`
    /// (new proxy-through-backend flow). Path-only strings must be resolved
    /// against the configured base URL or `URLSession` rejects them with
    /// `NSURLErrorUnsupportedURL`.
    private static func resolveDownloadURL(_ urlString: String) -> URL? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let url = URL(string: trimmed), let scheme = url.scheme, !scheme.isEmpty {
            return url
        }
        let base = AppBackendConfiguration.baseURL
        let separator = trimmed.hasPrefix("/") ? "" : "/"
        return URL(string: base + separator + trimmed)
    }

    private func sanitizedDownloadFileName(_ suggestedName: String) -> String {
        let fileName = URL(fileURLWithPath: suggestedName).lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !fileName.isEmpty, fileName != ".", fileName != ".." {
            return fileName
        }
        return "release-\(UUID().uuidString).zip"
    }

    private func sendWithRetry<Response: Decodable>(
        _ request: URLRequest,
        path: String,
        config: AppBackendEndpointConfig
    ) async throws -> Response {
        try enforceRateLimitCooldown(path: path)

        var attempt = 0
        while true {
            attempt += 1
            try Task.checkCancellation()

            do {
                return try await performHTTPRequest(request, path: path)
            } catch let error as AppBackendError {
                guard attempt < config.maxAttempts, isRetryable(error) else {
                    throw error
                }
                let delay = config.initialBackoff * pow(2.0, Double(attempt - 1))
                #if DEBUG
                Self.logger.debug("retrying path=\(path, privacy: .public) attempt=\(attempt, privacy: .public) delay=\(delay, privacy: .public)s reason=\(String(describing: error), privacy: .public)")
                #endif
                try await Task.sleep(for: .seconds(delay))
            }
        }
    }

    /// Throws a synthetic 429 (without touching the network) while the
    /// previously-observed `Retry-After` window is still open. Clears the
    /// cooldown once it has elapsed.
    private func enforceRateLimitCooldown(path: String) throws {
        guard let until = rateLimitedUntil else { return }
        if Date() < until {
            #if DEBUG
            Self.logger.debug("short-circuit (cooldown) path=\(path, privacy: .public) until=\(until.timeIntervalSinceNow, privacy: .public)s")
            #endif
            throw AppBackendError.http(
                statusCode: 429,
                payload: AppBackendErrorDTO(
                    code: "rate_limited",
                    message: "Too many requests. Please try again later."
                )
            )
        }
        rateLimitedUntil = nil
    }

    private func registerRateLimit(retryAfter rawHeader: String?) {
        let interval = parseRetryAfterInterval(rawHeader) ?? 30
        // Cap at 5 min to avoid being trapped if the server sends a bogus value.
        let clamped = min(max(interval, 1), 300)
        rateLimitedUntil = Date().addingTimeInterval(clamped)
        #if DEBUG
        Self.logger.debug("rate-limit cooldown armed for \(clamped, privacy: .public)s (Retry-After=\(rawHeader ?? "nil", privacy: .public))")
        #endif
    }

    private func parseRetryAfterInterval(_ raw: String?) -> TimeInterval? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        if let seconds = TimeInterval(raw) {
            return seconds
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
        if let date = formatter.date(from: raw) {
            return date.timeIntervalSinceNow
        }
        return nil
    }

    private func performHTTPRequest<Response: Decodable>(
        _ request: URLRequest,
        path: String
    ) async throws -> Response {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch let urlError as URLError {
            throw AppBackendError.transport(urlError)
        } catch {
            throw AppBackendError.unknown(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppBackendError.invalidURL
        }

        if !(200..<300).contains(httpResponse.statusCode) {
            let payload = try? JSONDecoder().decode(AppBackendErrorDTO.self, from: data)
            logHTTPError(path: path, status: httpResponse.statusCode, payload: payload)
            if httpResponse.statusCode == 429 {
                registerRateLimit(retryAfter: httpResponse.value(forHTTPHeaderField: "Retry-After"))
            }
            throw AppBackendError.http(statusCode: httpResponse.statusCode, payload: payload)
        }

        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw AppBackendError.decoding(error.localizedDescription)
        }
    }

    /// Only transient failures are retryable. Domain errors (license_revoked,
    /// rate_limited, etc.) and client mistakes (4xx) must never be retried —
    /// retrying them would not change the outcome and may abuse rate limits.
    private func isRetryable(_ error: AppBackendError) -> Bool {
        switch error {
        case .transport(let urlError):
            switch urlError.code {
            case .timedOut,
                 .cannotConnectToHost,
                 .cannotFindHost,
                 .dnsLookupFailed,
                 .networkConnectionLost:
                return true
            default:
                return false
            }
        case .http(let statusCode, _):
            // Only retry on bad-gateway / service-unavailable / gateway-timeout,
            // which are typical of cold starts and transient backend hiccups.
            return statusCode == 502 || statusCode == 503 || statusCode == 504
        case .missingConfiguration, .invalidURL, .decoding, .unknown:
            return false
        }
    }

    private func logHTTPError(path: String, status: Int, payload: AppBackendErrorDTO?) {
        #if DEBUG
        Self.logger.error("Backend HTTP error path=\(path, privacy: .public) status=\(status, privacy: .public) code=\(payload?.code ?? "-", privacy: .public)")
        #endif
    }
}

extension AppBackendError {
    var asLicenseOperationError: LicenseOperationError {
        switch self {
        case .missingConfiguration:
            return .fallback(BackendFallbackNotice(
                userMessage: AppMessages.text(.serviceUnavailable),
                supportCode: "LICENSE_SERVICE_UNAVAILABLE",
                canRetry: false,
                preservesCachedData: true
            ))
        case .invalidURL:
            return .fallback(BackendFallbackNotice(
                userMessage: AppMessages.text(.serviceUnavailable),
                supportCode: "LICENSE_SERVICE_UNAVAILABLE",
                canRetry: false,
                preservesCachedData: true
            ))
        case .http(let statusCode, let payload):
            if let payload, isDomainError(statusCode: statusCode, code: payload.code) {
                let friendly = AppMessages.backendErrorText(
                    code: payload.code,
                    backendMessage: payload.message,
                    default: AppMessages.text(.unexpectedError)
                )
                return .backend(LicenseOperationMessage(code: payload.code, message: friendly))
            }
            return .fallback(fallbackNotice(forHTTPStatusCode: statusCode, payload: payload))
        case .decoding:
            return .fallback(BackendFallbackNotice(
                userMessage: AppMessages.text(.licenseRefreshFailed),
                supportCode: "LICENSE_RESPONSE_INVALID",
                canRetry: true,
                preservesCachedData: true
            ))
        case .transport(let urlError):
            return .fallback(transportFallbackNotice(for: urlError))
        case .unknown:
            return .fallback(BackendFallbackNotice(
                userMessage: AppMessages.text(.licenseRefreshFailed),
                supportCode: "LICENSE_REFRESH_FAILED",
                canRetry: true,
                preservesCachedData: true
            ))
        }
    }

    private func isDomainError(statusCode: Int, code: String) -> Bool {
        let domainCodes: Set<String> = [
            "license_not_found",
            "license_suspended",
            "license_revoked",
            "license_expired",
            "license_unavailable",
            "activation_limit_reached",
            "fingerprint_mismatch",
            "beta_channel_disabled",
            // The code the backend actually answers today when a beta license
            // reaches the Cryptlex-routed validate path. Without it, its 403
            // fell into the generic 401/403 bucket and the user was told the
            // session was invalid — a retry-forever dead end instead of the
            // one sentence that explains what happened.
            "beta_edition_not_supported",
            "download_not_allowed",
            "release_not_found",
            "release_file_not_found",
            "release_archived"
        ]
        return domainCodes.contains(code.lowercased())
    }

    private func fallbackNotice(forHTTPStatusCode statusCode: Int, payload: AppBackendErrorDTO?) -> BackendFallbackNotice {
        let canRetry: Bool
        let supportCodeFallback: String
        let defaultText: String

        switch statusCode {
        case 400:
            canRetry = true
            supportCodeFallback = "LICENSE_REFRESH_REJECTED"
            defaultText = AppMessages.text(.licenseRefreshFailed)
        case 401, 403:
            canRetry = false
            supportCodeFallback = "LICENSE_SERVICE_AUTH"
            defaultText = AppMessages.text(.sessionInvalid)
        case 404:
            canRetry = false
            supportCodeFallback = "LICENSE_SERVICE_UNAVAILABLE"
            defaultText = AppMessages.text(.serviceUnavailable)
        case 408:
            canRetry = true
            supportCodeFallback = "LICENSE_SERVICE_TIMEOUT"
            defaultText = AppMessages.text(.licenseRefreshTimeout)
        case 429:
            canRetry = true
            supportCodeFallback = "LICENSE_RATE_LIMITED"
            defaultText = AppMessages.text(.tooManyRequests)
        case 500...599:
            canRetry = true
            supportCodeFallback = "LICENSE_SERVER_UNAVAILABLE"
            defaultText = AppMessages.text(.serviceUnavailable)
        default:
            canRetry = true
            supportCodeFallback = "LICENSE_REFRESH_FAILED"
            defaultText = AppMessages.text(.licenseRefreshFailed)
        }

        return BackendFallbackNotice(
            userMessage: AppMessages.backendErrorText(
                code: payload?.code,
                backendMessage: payload?.message,
                default: defaultText
            ),
            supportCode: supportCode(for: payload?.code, fallback: supportCodeFallback),
            canRetry: canRetry,
            preservesCachedData: true
        )
    }

    /// Derives a stable support code for the UI from the backend error code.
    /// The new MCBackend contract no longer ships a dedicated `supportCode`
    /// field, so we promote the documented `code` (e.g. `session_expired`,
    /// `rate_limited`) into an upper-cased token and fall back to the local
    /// default when the backend did not return a code at all.
    private func supportCode(for code: String?, fallback: String) -> String {
        guard let code = code?.trimmingCharacters(in: .whitespacesAndNewlines), !code.isEmpty else {
            return fallback
        }
        return code.uppercased()
    }

    private func transportFallbackNotice(for urlError: URLError) -> BackendFallbackNotice {
        switch urlError.code {
        case .timedOut:
            return BackendFallbackNotice(
                userMessage: AppMessages.text(.licenseRefreshTimeout),
                supportCode: "LICENSE_SERVICE_TIMEOUT",
                canRetry: true,
                preservesCachedData: true
            )
        case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
            return BackendFallbackNotice(
                userMessage: "Could not reach the license service. Saved license data is still being used.",
                supportCode: "LICENSE_OFFLINE",
                canRetry: true,
                preservesCachedData: true
            )
        default:
            return BackendFallbackNotice(
                userMessage: "Could not reach the license service. Saved license data is still being used.",
                supportCode: "LICENSE_OFFLINE",
                canRetry: true,
                preservesCachedData: true
            )
        }
    }
}

private final class AppBackendDownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let destinationURL: URL
    private let knownFileSize: Int64?
    private let onProgress: @Sendable (_ fraction: Double, _ bytesWritten: Int64, _ bytesTotal: Int64) -> Void
    private var continuation: CheckedContinuation<URL, Error>?
    /// Coalesces `didWriteData` callbacks: URLSession can fire hundreds of
    /// these per second; spamming a `Task { @MainActor }` for every chunk
    /// floods the main actor and makes the progress bar appear stuck. We
    /// only forward updates when the fraction advances >= 1% (or hits 1.0).
    private var lastReportedFraction: Double = -1

    init(destinationURL: URL, knownFileSize: Int64?, onProgress: @escaping @Sendable (_ fraction: Double, _ bytesWritten: Int64, _ bytesTotal: Int64) -> Void) {
        self.destinationURL = destinationURL
        self.knownFileSize = knownFileSize
        self.onProgress = onProgress
        super.init()
    }

    func setContinuation(_ continuation: CheckedContinuation<URL, Error>) {
        self.continuation = continuation
    }

    private func fileSize(at url: URL) -> Int64 {
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value
        return size ?? -1
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let total = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : (knownFileSize ?? 0)
        #if DEBUG
        if totalBytesWritten == bytesWritten {
            print("[Download] first chunk — totalBytesExpectedToWrite=\(totalBytesExpectedToWrite) knownFileSize=\(knownFileSize ?? -1) total=\(total)")
        }
        #endif
        guard total > 0 else { return }
        let fraction = Double(totalBytesWritten) / Double(total)
        let isComplete = totalBytesWritten >= total
        guard fraction - lastReportedFraction >= 0.01 || isComplete else { return }
        lastReportedFraction = fraction
        #if DEBUG
        print("[Download] progress=\(String(format: "%.2f", fraction)) written=\(totalBytesWritten)/\(total)")
        #endif
        onProgress(fraction, totalBytesWritten, total)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        do {
            let fm = FileManager.default
            #if DEBUG
            print("[Download] didFinishDownloading temp=\(location.path) tempSize=\(fileSize(at: location))")
            #endif
            if fm.fileExists(atPath: destinationURL.path) {
                try fm.removeItem(at: destinationURL)
            }
            try fm.moveItem(at: location, to: destinationURL)
            #if DEBUG
            let finalSize = fileSize(at: destinationURL)
            print("[Download] movedTo=\(destinationURL.path) finalSize=\(finalSize) expected=\(knownFileSize ?? -1)")
            if let knownFileSize, knownFileSize > 0, finalSize != knownFileSize {
                print("[Download] WARNING size mismatch final=\(finalSize) expected=\(knownFileSize)")
            }
            if finalSize <= 0 {
                print("[Download] WARNING downloaded file is empty or unreadable")
            }
            #endif
        } catch {
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        defer {
            continuation = nil
            session.finishTasksAndInvalidate()
        }
        if let error {
            continuation?.resume(throwing: error)
            return
        }
        guard let httpResponse = task.response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (task.response as? HTTPURLResponse)?.statusCode ?? 0
            #if DEBUG
            print("[Download] HTTP failure status=\(statusCode) savedSize=\(fileSize(at: destinationURL))")
            #endif
            continuation?.resume(throwing: AppBackendError.http(statusCode: statusCode, payload: nil))
            return
        }
        #if DEBUG
        print("[Download] completed HTTP status=\(httpResponse.statusCode) contentLength=\(httpResponse.expectedContentLength) savedSize=\(fileSize(at: destinationURL)) mime=\(httpResponse.mimeType ?? "-")")
        #endif
        continuation?.resume(returning: destinationURL)
    }
}
