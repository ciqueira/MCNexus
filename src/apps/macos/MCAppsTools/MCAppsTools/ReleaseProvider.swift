import Foundation

// MARK: - App-level models

struct ReleaseInfo: Sendable, Identifiable {
    static let currentPlatform = "macos"

    let id: String
    let name: String
    let version: String
    let channel: String
    let platform: String
    let updatedAt: String?
    let publishedAt: String?
    let totalFiles: Int

    var isCurrentPlatform: Bool {
        platform.caseInsensitiveCompare(Self.currentPlatform) == .orderedSame
    }
}

struct DownloadStats: Sendable, Equatable {
    let fraction: Double
    let bytesWritten: Int64
    let bytesTotal: Int64
}

enum DownloadProgress: Sendable {
    case downloading(DownloadStats)
    case completed(localURL: URL)
}

// MARK: - Protocol

protocol ReleaseProvider: Sendable {
    /// The releases the backend last returned FOR THIS LICENCE.
    ///
    /// Per licence, not per product: a single OpenKey `productID` can back
    /// several products at once (see `BackendReleasesCache`), so a
    /// product-keyed lookup answers with a sibling product's releases.
    func listReleases(licenseKey: String) async throws -> [ReleaseInfo]

    /// Download a release file to a temporary location.
    ///
    /// `channel` decides what happens when the backend's resolve-download
    /// response carries no SHA256 for the asset: `stable` refuses to
    /// install, `beta` installs with a logged warning
    /// (PLAN_Release_Integrity_And_Listing.md §2.4). A mismatch — the digest
    /// present but wrong — is refused in every channel; that part never
    /// depends on this argument.
    func downloadRelease(releaseId: String, productID: String, licenseKey: String?, channel: String, progress: @escaping @Sendable (DownloadProgress) -> Void) async throws -> URL
}
