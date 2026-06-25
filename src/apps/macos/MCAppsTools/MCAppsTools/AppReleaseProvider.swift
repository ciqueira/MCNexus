import Foundation

final class AppReleaseProvider: ReleaseProvider, @unchecked Sendable {
    private let backendService: AppBackendService
    private let releasesCache: BackendReleasesCache
    private let machineFingerprintProvider: @Sendable () -> String

    init(
        backendService: AppBackendService = AppBackendService(),
        releasesCache: BackendReleasesCache = BackendReleasesCache(),
        machineFingerprintProvider: @escaping @Sendable () -> String = { MachineFingerprint.generate() }
    ) {
        self.backendService = backendService
        self.releasesCache = releasesCache
        self.machineFingerprintProvider = machineFingerprintProvider
    }

    convenience init(licenseProvider: AppLicenseBackendProvider) {
        self.init(
            backendService: licenseProvider.sharedBackendService,
            releasesCache: licenseProvider.sharedReleasesCache
        )
    }

    func listReleases(productID: String) async throws -> [ReleaseInfo] {
        await releasesCache.releases(for: productID).filter(\.isCurrentPlatform)
    }

    func latestRelease(productID: String) async throws -> ReleaseInfo? {
        try await listReleases(productID: productID).first
    }

    func downloadRelease(
        releaseId: String,
        productID: String,
        licenseKey: String?,
        progress: @escaping @Sendable (DownloadProgress) -> Void
    ) async throws -> URL {
        guard let licenseKey else {
            throw AppBackendError.http(statusCode: 400, payload: AppBackendErrorDTO(
                code: "missing_token",
                message: "License key is required"
            ))
        }

        let sessionToken = await backendService.sessionTokens.token(for: licenseKey)

        let request = ResolveDownloadRequestDTO(
            platform: "macos",
            machineFingerprint: machineFingerprintProvider()
        )

        let resolved = try await backendService.resolveDownload(
            releaseId: releaseId,
            request: request,
            sessionToken: sessionToken
        )

        let initialTotal = resolved.fileSize.map { Int64($0) } ?? 0
        progress(.downloading(DownloadStats(fraction: 0.0, bytesWritten: 0, bytesTotal: initialTotal)))
        let localURL = try await backendService.downloadFile(
            from: resolved.url,
            suggestedName: resolved.name,
            knownFileSize: resolved.fileSize.map { Int64($0) }
        ) { fraction, bytesWritten, bytesTotal in
            progress(.downloading(DownloadStats(fraction: fraction, bytesWritten: bytesWritten, bytesTotal: bytesTotal)))
        }
        progress(.completed(localURL: localURL))
        return localURL
    }
}
