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
    /// List all available releases for the product
    func listReleases(productID: String) async throws -> [ReleaseInfo]

    /// Get the latest release
    func latestRelease(productID: String) async throws -> ReleaseInfo?

    /// Download a release file to a temporary location
    func downloadRelease(releaseId: String, productID: String, licenseKey: String?, progress: @escaping @Sendable (DownloadProgress) -> Void) async throws -> URL
}
