//
//  ContentView.swift
//  MCAppsTools
//
//  Created by Magno Ciqueira on 28/04/2026.
//

import SwiftUI
import CryptoKit
#if os(macOS)
import AppKit
#endif

enum PluginLifecycleState: String, Codable {
    case idle
    case activating
    case active
    case updateAvailable
    case suspended
    case deactivating
}

enum InstallationFeedback: Equatable {
    case success(String?)
    case warning(String?)
    case error(String?)

    var message: String {
        switch self {
        case .success(let message):
            return message ?? "Installation completed successfully"
        case .warning(let message):
            return message ?? ""
        case .error(let message):
            return message ?? "Installation error"
        }
    }

    var color: Color {
        switch self {
        case .success:
            return .green
        case .warning:
            return Color(red: 0.98, green: 0.72, blue: 0.28)
        case .error:
            return .red
        }
    }
}

enum InstallationStep: CaseIterable, Hashable {
    case validatingLicense
    case downloadingRelease
    case installingPlugin
    case activatingLicense

    var label: String {
        switch self {
        case .validatingLicense: return "Validating license"
        case .downloadingRelease: return "Downloading release"
        case .installingPlugin: return "Installing plugin"
        case .activatingLicense: return "Activating license on this machine"
        }
    }
}

enum StepStatus {
    case pending
    case inProgress
    case completed
    case failed
}

/// Header headline rotation: one of these is shown at a time, swapped only
/// when a license sync completes successfully (see `rotateHeaderHeadline()`),
/// never mid-session, so the change reads as "the app opened this way" rather
/// than a visible transition.
let appHeaderHeadlines = [
    "Apps Tools for Editing",
    "Apps Tools for Effects",
    "Apps Tools for Color",
    "Apps Tools for Finishing",
    "Apps Tools for Post-Production"
]

enum LicenseSyncState {
    case idle
    case syncing
    case synced
    case failed

    var message: String {
        switch self {
        case .idle:
            return "Using saved data"
        case .syncing:
            return "Syncing latest status..."
        case .synced:
            return "Status updated"
        case .failed:
            return "Could not refresh latest status"
        }
    }

    var color: Color {
        switch self {
        case .idle:
            return .white.opacity(0.62)
        case .syncing:
            return Color(red: 0.36, green: 0.68, blue: 0.98)
        case .synced:
            return Color(red: 0.37, green: 0.88, blue: 0.63)
        case .failed:
            return Color(red: 0.95, green: 0.43, blue: 0.40)
        }
    }
}

enum LicenseEdition: String, Codable {
    case full = "Full"
    case demo = "Demo"
    case trial = "Trial"
    case beta = "beta"

    init(from sdkEdition: LicenseEditionType) {
        switch sdkEdition {
        case .demo: self = .demo
        case .trial: self = .trial
        case .beta: self = .beta
        case .full: self = .full
        }
    }
}

struct ReleaseVersionInfo: Codable, Hashable, Sendable {
    let version: String
    let channel: String

    var isBeta: Bool { channel.lowercased() == "beta" }
}

struct PersistedLicense: Codable {
    let id: UUID
    var product: AppProduct
    var pluginName: String
    var edition: LicenseEdition
    var installedVersion: String?
    var availableVersion: String?
    var lastKnownLicenseKey: String?
    var activationDate: String
    var pluginUpdateDate: String
    var activationUsage: String
    var deactivationDate: String?
    var previousVersions: [ReleaseVersionInfo]
    var lifecycleState: PluginLifecycleState
    var isRevoked: Bool
    var installedBundleNames: [String]
    var skipLocalActivation: Bool
    /// Schema 2 (Fase 5). Absent on every record written before this field
    /// existed — decodes to `nil`, which `LicenseRuntimeRouter` resolves to
    /// Cryptlex, i.e. identical behavior to every such record today.
    var runtime: LicenseRuntime?
    var tenantId: String?
    /// Schema 3. The SDK's own id for this machine's activation, recorded the
    /// first time the SDK confirms it holds this key. It exists because
    /// NexKeyRuntime's ABI never hands a raw licence key back: without a
    /// stable id, "is the SDK's local state about MY key?" can only be
    /// answered from an in-memory cache that dies with the process, and every
    /// relaunch silently stopped consulting the SDK at all. Absent on older
    /// records — decodes to nil, which simply means "cannot adopt yet".
    var activationId: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case product
        case pluginName
        case edition
        case installedVersion
        case availableVersion
        case lastKnownLicenseKey
        case activationDate
        case pluginUpdateDate
        case activationUsage
        case deactivationDate
        case previousVersions
        case lifecycleState
        case isRevoked
        case installedBundleNames
        case skipLocalActivation
        case runtime
        case tenantId
        case activationId
    }

    nonisolated init(
        id: UUID,
        product: AppProduct,
        pluginName: String,
        edition: LicenseEdition,
        installedVersion: String?,
        availableVersion: String?,
        lastKnownLicenseKey: String?,
        activationDate: String,
        pluginUpdateDate: String,
        activationUsage: String,
        deactivationDate: String?,
        previousVersions: [ReleaseVersionInfo],
        lifecycleState: PluginLifecycleState,
        isRevoked: Bool = false,
        installedBundleNames: [String] = [],
        skipLocalActivation: Bool = false,
        runtime: LicenseRuntime? = nil,
        tenantId: String? = nil,
        activationId: String? = nil
    ) {
        self.id = id
        self.product = product
        self.pluginName = pluginName
        self.edition = edition
        self.installedVersion = installedVersion
        self.availableVersion = availableVersion
        self.lastKnownLicenseKey = lastKnownLicenseKey
        self.activationDate = activationDate
        self.pluginUpdateDate = pluginUpdateDate
        self.activationUsage = activationUsage
        self.deactivationDate = deactivationDate
        self.previousVersions = previousVersions
        self.lifecycleState = lifecycleState
        self.isRevoked = isRevoked
        self.installedBundleNames = installedBundleNames
        self.skipLocalActivation = skipLocalActivation
        self.runtime = runtime
        self.tenantId = tenantId
        self.activationId = activationId
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        pluginName = try container.decode(String.self, forKey: .pluginName)
        edition = try container.decode(LicenseEdition.self, forKey: .edition)
        installedVersion = try container.decodeIfPresent(String.self, forKey: .installedVersion)
        availableVersion = try container.decodeIfPresent(String.self, forKey: .availableVersion)
        lastKnownLicenseKey = try container.decodeIfPresent(String.self, forKey: .lastKnownLicenseKey)
        activationDate = try container.decode(String.self, forKey: .activationDate)
        pluginUpdateDate = try container.decode(String.self, forKey: .pluginUpdateDate)
        activationUsage = try container.decode(String.self, forKey: .activationUsage)
        deactivationDate = try container.decodeIfPresent(String.self, forKey: .deactivationDate)
        if let infos = try? container.decode([ReleaseVersionInfo].self, forKey: .previousVersions) {
            previousVersions = infos
        } else if let legacyVersions = try? container.decode([String].self, forKey: .previousVersions) {
            previousVersions = legacyVersions.map { ReleaseVersionInfo(version: $0, channel: "stable") }
        } else {
            previousVersions = []
        }
        lifecycleState = try container.decode(PluginLifecycleState.self, forKey: .lifecycleState)
        isRevoked = try container.decodeIfPresent(Bool.self, forKey: .isRevoked) ?? false
        installedBundleNames = try container.decodeIfPresent([String].self, forKey: .installedBundleNames) ?? []
        skipLocalActivation = try container.decodeIfPresent(Bool.self, forKey: .skipLocalActivation) ?? false
        runtime = try container.decodeIfPresent(LicenseRuntime.self, forKey: .runtime)
        tenantId = try container.decodeIfPresent(String.self, forKey: .tenantId)
        activationId = try container.decodeIfPresent(String.self, forKey: .activationId)
        product = try container.decodeIfPresent(AppProduct.self, forKey: .product)
            ?? AppProductCatalog.configuredProducts().first
            ?? AppProduct(name: pluginName, productID: pluginName)
    }
}

struct PluginLicenseItem: Identifiable, Equatable {
    let id: UUID
    var product: AppProduct
    var pluginName: String
    var edition: LicenseEdition
    var installedVersion: String?
    var availableVersion: String?
    var activatedLicenseKey: String?
    var lastKnownLicenseKey: String?
    var activationDate: String
    var pluginUpdateDate: String
    var activationUsage: String
    var deactivationDate: String?
    var previousVersions: [ReleaseVersionInfo]
    var lifecycleState: PluginLifecycleState
    var isShowingPreviousVersions: Bool
    var isInitialStatusLoad: Bool
    var isRevoked: Bool
    var installationFeedback: InstallationFeedback?
    var installedBundleNames: [String]
    var skipLocalActivation: Bool
    /// Schema 2 (Fase 5) — see `PersistedLicense.runtime`.
    var runtime: LicenseRuntime?
    var tenantId: String?
    /// Schema 3 — see `PersistedLicense.activationId`.
    var activationId: String?

    /// True when the license is in the deactivated state but no key is
    /// recoverable locally — the on-disk credential file (`.dat`) was wiped
    /// out-of-band. Retry Installation would no-op because it needs the key,
    /// so the UI hides it and surfaces only Remove Key / Remove Plugin.
    var isCorrupted: Bool {
        lifecycleState == .deactivating && lastKnownLicenseKey == nil && !isRevoked
    }

    var hasInstalledPlugin: Bool {
        installedVersion != nil && !installedBundleNames.isEmpty
    }

    var hasSavedLicense: Bool {
        lastKnownLicenseKey != nil || activatedLicenseKey != nil
    }

    var isLicenseRemovedOnThisMachine: Bool {
        lifecycleState == .deactivating &&
            !isCorrupted &&
            !isRevoked &&
            hasSavedLicense &&
            hasInstalledPlugin
    }

    var isPluginRemoved: Bool {
        lifecycleState == .deactivating &&
            !isCorrupted &&
            !isRevoked &&
            !hasInstalledPlugin
    }

    var isPluginMissing: Bool {
        (lifecycleState == .active || lifecycleState == .updateAvailable) &&
            !isCorrupted &&
            !isRevoked &&
            hasSavedLicense &&
            !hasInstalledPlugin
    }

    nonisolated func toPersisted() -> PersistedLicense {
        PersistedLicense(
            id: id,
            product: product,
            pluginName: pluginName,
            edition: edition,
            installedVersion: installedVersion,
            availableVersion: availableVersion,
            lastKnownLicenseKey: lastKnownLicenseKey,
            activationDate: activationDate,
            pluginUpdateDate: pluginUpdateDate,
            activationUsage: activationUsage,
            deactivationDate: deactivationDate,
            previousVersions: previousVersions,
            lifecycleState: lifecycleState,
            isRevoked: isRevoked,
            installedBundleNames: installedBundleNames,
            skipLocalActivation: skipLocalActivation,
            runtime: runtime,
            tenantId: tenantId,
            activationId: activationId
        )
    }

    nonisolated static func fromPersisted(_ p: PersistedLicense, sdkActive: Bool) -> PluginLicenseItem {
        // When skipLocalActivation is true, the SDK has no record of this
        // license — treat it as locally active based on persisted state alone.
        let resolvedActive = p.skipLocalActivation || sdkActive
        return PluginLicenseItem(
            id: p.id,
            product: p.product,
            pluginName: p.pluginName,
            edition: p.edition,
            installedVersion: p.installedVersion,
            availableVersion: p.availableVersion,
            activatedLicenseKey: resolvedActive ? p.lastKnownLicenseKey : nil,
            lastKnownLicenseKey: p.lastKnownLicenseKey,
            activationDate: p.activationDate,
            pluginUpdateDate: p.pluginUpdateDate,
            activationUsage: p.activationUsage,
            deactivationDate: p.deactivationDate,
            previousVersions: p.previousVersions,
            lifecycleState: p.isRevoked ? .deactivating : (resolvedActive ? (p.lifecycleState == .deactivating ? .deactivating : .active) : .deactivating),
            isShowingPreviousVersions: false,
            isInitialStatusLoad: true,
            isRevoked: p.isRevoked,
            installationFeedback: nil,
            installedBundleNames: p.installedBundleNames,
            skipLocalActivation: p.skipLocalActivation,
            runtime: p.runtime,
            tenantId: p.tenantId,
            activationId: p.activationId
        )
    }

    nonisolated static func fromCachedPersisted(_ p: PersistedLicense) -> PluginLicenseItem {
        PluginLicenseItem(
            id: p.id,
            product: p.product,
            pluginName: p.pluginName,
            edition: p.edition,
            installedVersion: p.installedVersion,
            availableVersion: p.availableVersion,
            activatedLicenseKey: p.lifecycleState == .deactivating ? nil : p.lastKnownLicenseKey,
            lastKnownLicenseKey: p.lastKnownLicenseKey,
            activationDate: p.activationDate,
            pluginUpdateDate: p.pluginUpdateDate,
            activationUsage: p.activationUsage,
            deactivationDate: p.deactivationDate,
            previousVersions: p.previousVersions,
            lifecycleState: p.lifecycleState,
            isShowingPreviousVersions: false,
            isInitialStatusLoad: false,
            isRevoked: p.isRevoked,
            installationFeedback: nil,
            installedBundleNames: p.installedBundleNames,
            skipLocalActivation: p.skipLocalActivation,
            runtime: p.runtime,
            tenantId: p.tenantId,
            activationId: p.activationId
        )
    }
}

struct PluginActionHandler {
    var activate: (String) -> Void
    var installUpdate: () -> Void
    var deactivate: () -> Void
    var removePlugin: () -> Void

    static let placeholder = PluginActionHandler(
        activate: { _ in },
        installUpdate: {},
        deactivate: {},
        removePlugin: {}
    )
}

struct AppUpdateInfo: Equatable {
    let version: String
    let downloadURL: URL
    let releaseNotes: String?
}

struct ContentView: View {
    private static let minimumBackendRefreshInterval: TimeInterval = 60

    private let activeLicensesAnchorID = "active-licenses"
    private let statusPanelAnchorID = "status-panel"
    private let activationPanelAnchorID = "activation-panel"
    private let diagnosticsAnchorID = "diagnostics"
    private let supportURL = URL(string: "https://github.com/ciqueira/MCNexus/issues")!
    private let activeLicenseColumns = Array(
        repeating: GridItem(.flexible(minimum: 0), spacing: 12, alignment: .top),
        count: 3
    )

    @State private var licenseKey = ""
    @State private var selectedActivationProductID: String
    @State private var selectedLicenseID: UUID?
    @FocusState private var isLicenseFieldFocused: Bool
    @State private var isShowingActivationPanel = false
    @State private var isShowingDeactivateConfirmation = false
    @State private var isShowingRemovePluginConfirmation = false
    @State private var activationErrorMessage: String?
    @State private var installationStepStatuses: [InstallationStep: StepStatus] = [:]
    @State private var installationFailed = false
    @State private var installationErrorDetail: String?
    @State private var downloadProgress: Double?
    @State private var downloadBytesWritten: Int64 = 0
    @State private var downloadBytesTotal: Int64 = 0
    @State private var downloadBytesPerSecond: Double = 0
    @State private var downloadLastSampleBytes: Int64 = 0
    @State private var downloadLastSampleTime: Date?
    @State private var deactivationErrorDetail: String?
    @State private var deactivationErrorLicenseID: UUID?
    @State private var scrollToAnchor: ((String) -> Void)?
    @State private var activeLicenses: [PluginLicenseItem] = []
    @State private var preInstallSnapshot: PluginLicenseItem?
    @State private var pendingTargetVersion: String?
    @State private var pendingActivateOnMachine = false
    @State private var pendingNewActivationLicenseID: UUID?
    @State private var installationTargetVersion: String?
    @State private var licenseSyncState: LicenseSyncState = .idle
    @State private var syncIconRotationDegrees: Double = 0
    @State private var headerHeadline: String = appHeaderHeadlines.randomElement() ?? "Apps Tools for Color"
    @State private var licenseSyncNotice: BackendFallbackNotice?
    @State private var persistenceErrorMessage: String?
    @State private var lastSuccessfulLicenseSyncDate: Date?
    @State private var lastLicenseRefreshAttemptDate: Date?
    @State private var isLicenseRefreshInFlight = false
    @State private var licenseRefreshTask: Task<Void, Never>?
    @State private var licenseRetryCooldownRemaining = 0
    @State private var upgradedLicenseIDs: Set<UUID> = []
    @State private var sdkPollingTask: Task<Void, Never>?
    @State private var backendHeartbeatTask: Task<Void, Never>?
    @State private var pendingAppUpdate: AppUpdateInfo?
    /// Version the user dismissed in the current session. Lives in-memory
    /// only — relaunching the app re-shows the banner, while the heartbeat in
    /// the same session respects the dismissal.
    @State private var dismissedAppUpdateVersion: String?

    private let workflowCoordinator: LicenseWorkflowCoordinator
    private let availableProducts: [AppProduct]

    let actions: PluginActionHandler

    init(actions: PluginActionHandler = .placeholder) {
        let workflowCoordinator = LicenseWorkflowCoordinator()
        let products = workflowCoordinator.products()
        self.workflowCoordinator = workflowCoordinator
        self.availableProducts = products
        _selectedActivationProductID = State(initialValue: products.first?.productID ?? "")
        self.actions = actions
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color(red: 34 / 255, green: 34 / 255, blue: 34 / 255)
                .ignoresSafeArea()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header

                        activeLicensesPanel
                            .id(activeLicensesAnchorID)

                        if let selectedLicense = selectedLicense {
                            statusPanel(for: selectedLicense)
                                .id(statusPanelAnchorID)
                        }

                        activationPanel
                            .id(activationPanelAnchorID)
                        diagnosticsInfo
                            .id(diagnosticsAnchorID)
                    }
                    .padding(28)
                    .frame(maxWidth: 920)
                }
                .onAppear {
                    scrollToAnchor = { anchorID in
                        withAnimation {
                            proxy.scrollTo(anchorID, anchor: .top)
                        }
                    }
                }
                .onChange(of: isShowingActivationPanel) { _, isShowing in
                    guard isShowing else {
                        return
                    }

                    withAnimation {
                        proxy.scrollTo(activationPanelAnchorID, anchor: .bottom)
                    }
                }
                .onChange(of: installationStepStatuses.isEmpty) { _, isEmpty in
                    guard !isEmpty else {
                        return
                    }

                    withAnimation {
                        proxy.scrollTo(statusPanelAnchorID, anchor: .top)
                    }
                }
            }

            if let pendingAppUpdate {
                appUpdateBanner(pendingAppUpdate)
                    .padding(.top, 20)
                    .padding(.trailing, 20)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .frame(width: 850, height: 800)
        .alert("Deactivate license?", isPresented: $isShowingDeactivateConfirmation) {
            Button("Deactivate License", role: .destructive) {
                deactivatePlugin()
            }

            Button("Cancel", role: .cancel) {
            }
        } message: {
            Text("This removes the license activation from this computer. Plugin files will stay installed.")
        }
        .alert("Remove plugin?", isPresented: $isShowingRemovePluginConfirmation) {
            Button("Remove Plugin", role: .destructive) {
                removePlugin()
            }

            Button("Cancel", role: .cancel) {
            }
        } message: {
            Text("This removes the plugin files from this computer. Your license key will stay saved.")
        }
        .task {
            loadCachedLicensesFromStorage()
            await reconcileLocalLicenseState()
            await workflowCoordinator.warmUpBackend()
            startBackgroundLicenseRefresh()
            await checkForAppUpdate()
            startBackgroundRefreshTimers()
        }
        #if os(macOS)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            startBackgroundRefreshTimers()
            guard !isActivatingNewLicense, installationStepStatuses.isEmpty else { return }
            startBackgroundLicenseRefresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            stopBackgroundRefreshTimers()
        }
        #endif
        .onChange(of: activeLicenses) { _, _ in
            saveLicenses()
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
    }

    /// Fase 5 (Round 6) — `mcnexus://activate|deactivate|refresh`, routed into
    /// the same private functions the in-app buttons already call. No
    /// confirmation dialog for `deactivate`: opening the link is itself the
    /// explicit action, unlike the in-app button which still shows one.
    private func handleDeepLink(_ url: URL) {
        guard url.scheme?.lowercased() == "mcnexus" else { return }

        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? {
            queryItems.first(where: { $0.name == name })?.value
        }

        switch url.host?.lowercased() {
        case "activate":
            guard let key = value("key"), !key.isEmpty else { return }
            licenseKey = key
            if let productID = value("product"),
               let product = availableProducts.first(where: { $0.productID == productID }) {
                selectedActivationProductID = product.productID
            }
            activatePlugin()

        case "deactivate":
            if let key = value("key") {
                if let match = activeLicenses.first(where: {
                    $0.lastKnownLicenseKey?.caseInsensitiveCompare(key) == .orderedSame
                        || $0.activatedLicenseKey?.caseInsensitiveCompare(key) == .orderedSame
                }) {
                    selectedLicenseID = match.id
                }
            }
            deactivatePlugin()

        case "refresh":
            Task {
                await refreshLicensesInBackground(force: true)
            }

        default:
            break
        }
    }

    private var selectedLicense: PluginLicenseItem? {
        guard let selectedLicenseID else {
            return activeLicenses.first
        }

        return activeLicenses.first(where: { $0.id == selectedLicenseID }) ?? activeLicenses.first
    }

    private var selectedActivationProduct: AppProduct? {
        availableProducts.first(where: { $0.productID == selectedActivationProductID })
            ?? availableProducts.first
            ?? AppProduct(name: "Resolving product", productID: "pending-product")
    }

    private var selectedLicenseIndex: Int? {
        guard let selectedLicense else {
            return nil
        }

        return activeLicenses.firstIndex(where: { $0.id == selectedLicense.id })
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(headerHeadline)
                .font(.custom("Proxima Nova", size: 34).weight(.bold))
                .foregroundStyle(.white)

            Text("Plugin and license management")
                .font(.custom("Proxima Nova", size: 18))
                .foregroundStyle(.white.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 8)
    }

    /// Picks the next header headline, excluding the current one so every
    /// sync attempt reads as a change. Fired the moment a sync starts, not
    /// when it finishes — the two are independent, just coincide in time.
    /// Direct state assignment with no animation, so it swaps silently on
    /// next render instead of transitioning.
    private func rotateHeaderHeadline() {
        let candidates = appHeaderHeadlines.filter { $0 != headerHeadline }
        headerHeadline = candidates.randomElement() ?? headerHeadline
    }

    @ViewBuilder
    private func appUpdateBanner(_ update: AppUpdateInfo) -> some View {
        let accentGradient = LinearGradient(
            colors: [
                Color(red: 1.00, green: 0.66, blue: 0.10),
                Color(red: 0.96, green: 0.45, blue: 0.05)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        HStack(spacing: 12) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(accentGradient)

            VStack(alignment: .leading, spacing: 1) {
                Text("Update available")
                    .font(.custom("Proxima Nova", size: 13).weight(.bold))
                    .foregroundStyle(.white)
                Text("Version \(update.version) is ready")
                    .font(.custom("Proxima Nova", size: 11))
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer(minLength: 6)

            Button {
                #if os(macOS)
                NSWorkspace.shared.open(update.downloadURL)
                #endif
            } label: {
                Text("Update")
                    .font(.custom("Proxima Nova", size: 12).weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(accentGradient, in: Capsule())
            }
            .buttonStyle(.plain)
            .pointerCursor()

            Button {
                withAnimation(.easeOut(duration: 0.25)) {
                    dismissedAppUpdateVersion = update.version
                    pendingAppUpdate = nil
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(width: 18, height: 18)
                    .background(.white.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)
            .pointerCursor()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Color(red: 34 / 255, green: 34 / 255, blue: 34 / 255),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .background(
            Color.white.opacity(0.04),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(accentGradient, lineWidth: 1.5)
        )
        .fixedSize()
    }

    private var activationPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 10) {
                Button {
                    isShowingActivationPanel.toggle()
                    if isShowingActivationPanel {
                        isLicenseFieldFocused = true
                    }
                } label: {
                    Text(isShowingActivationPanel ? "New license activation" : "Activate another license")
                        .font(.custom("Proxima Nova", size: 15).weight(.semibold))
                        .foregroundStyle(.white)
                        .pointerCursor()
                }
                .buttonStyle(.plain)
                .disabled(isActivatingNewLicense)

                if let activationErrorMessage {
                    Text(activationErrorMessage)
                        .font(.custom("Proxima Nova", size: 13).weight(.semibold))
                        .foregroundStyle(.red)
                }
            }

            if isShowingActivationPanel {
                activationInputForm
            }
        }
        .panelStyle()
        .disabled(!installationStepStatuses.isEmpty)
    }

    private var activationInputForm: some View {
        VStack(alignment: .leading, spacing: 18) {
            if availableProducts.count > 1 {
                Picker("Product", selection: $selectedActivationProductID) {
                    ForEach(availableProducts, id: \.productID) { product in
                        Text(product.displayName).tag(product.productID)
                    }
                }
                .pickerStyle(.menu)
                .tint(.white)
            }

            TextField("Paste your key here", text: $licenseKey, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(.white.opacity(0.06))
                .foregroundStyle(.white)
                .focused($isLicenseFieldFocused)
                .onChange(of: licenseKey) { _, _ in
                    activationErrorMessage = nil
                }

            HStack(spacing: 14) {
                Button(action: activatePlugin) {
                    Text("Activate Plugin")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .pointerCursor()
                .disabled(licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isActivatingNewLicense)
            }
        }
    }

    private var installationProgressView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(installationTargetText)
                .font(.custom("Proxima Nova", size: 13).weight(.semibold))
                .foregroundStyle(Color(red: 0.36, green: 0.68, blue: 0.98))

            ForEach(InstallationStep.allCases, id: \.self) { step in
                HStack(alignment: .top, spacing: 12) {
                    Group {
                        switch installationStepStatuses[step, default: .pending] {
                        case .pending:
                            Image(systemName: "circle")
                                .foregroundStyle(.white.opacity(0.3))
                        case .inProgress:
                            ProgressView()
                                .controlSize(.small)
                        case .completed:
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color(red: 0.37, green: 0.88, blue: 0.63))
                        case .failed:
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color(red: 0.95, green: 0.43, blue: 0.40))
                        }
                    }
                    .frame(width: 16, height: 16)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(step.label)
                                .font(.custom("Proxima Nova", size: 14).weight(.medium))
                                .foregroundStyle(stepTextColor(for: installationStepStatuses[step, default: .pending]))

                            if installationStepStatuses[step] == .failed, let detail = installationErrorDetail {
                                Text("— \(detail)")
                                    .font(.custom("Proxima Nova", size: 13).weight(.semibold))
                                    .foregroundStyle(Color(red: 0.95, green: 0.43, blue: 0.40))
                                    .textSelection(.enabled)
                            }
                        }

                        if step == .downloadingRelease {
                            let status = installationStepStatuses[step]
                            if status == .inProgress, let progress = downloadProgress {
                                VStack(alignment: .leading, spacing: 4) {
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            Capsule()
                                                .fill(.white.opacity(0.12))
                                                .frame(height: 4)
                                            Capsule()
                                                .fill(Color(red: 0.36, green: 0.68, blue: 0.98))
                                                .frame(width: max(4, geo.size.width * progress), height: 4)
                                                .animation(.linear(duration: 0.1), value: progress)
                                        }
                                    }
                                    .frame(maxWidth: 220, maxHeight: 4)

                                    if downloadBytesTotal > 0 {
                                        Text(downloadProgressText)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(.white.opacity(0.55))
                                            .monospacedDigit()
                                    }
                                }
                            } else if status == .completed, downloadBytesTotal > 0 {
                                Text(formatBytes(downloadBytesTotal))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.55))
                                    .monospacedDigit()
                            }
                        }

                        if step == .installingPlugin {
                            Text("/Library/OFX/Plugins")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.4))
                                .textSelection(.enabled)
                        }
                    }
                }
            }
        }
    }

    private var installationTargetText: String {
        guard let installationTargetVersion, !installationTargetVersion.isEmpty else {
            return "Preparing installation..."
        }

        return "Installing version \(installationTargetVersion)"
    }

    private var diagnosticsInfo: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("Fingerprint ID \(diagnosticsFingerprintCopyValue)")
                    .font(.custom("Proxima Nova", size: 13).weight(.medium))
                    .foregroundStyle(.white.opacity(0.82))

                Button("Copy for diagnostics") {
                    copyDiagnostics()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .pointerCursor()
            }

            HStack(spacing: 12) {
                Text("App Client Version \(appClientVersion)")
                    .font(.custom("Proxima Nova", size: 13))
                    .foregroundStyle(.white.opacity(0.62))

                if let licenseSyncNotice, licenseSyncState == .failed, let supportCode = licenseSyncNotice.supportCode {
                    Text("Support code: \(supportCode)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color(red: 0.95, green: 0.43, blue: 0.40).opacity(0.82))
                        .textSelection(.enabled)
                }
            }

            if let persistenceErrorMessage {
                Text(persistenceErrorMessage)
                    .font(.custom("Proxima Nova", size: 13).weight(.medium))
                    .foregroundStyle(Color(red: 0.95, green: 0.43, blue: 0.40))
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var activeLicensesPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Text("Active licenses")
                    .font(.custom("Proxima Nova", size: 16).weight(.semibold))
                    .foregroundStyle(.white.opacity(0.92))

                Spacer()

                Label {
                    Text(licenseSyncState.message)
                } icon: {
                    Image(systemName: syncStatusIcon)
                        .rotationEffect(.degrees(syncIconRotationDegrees))
                        .frame(width: 18, height: 18)
                        .clipped()
                }
                .font(.custom("Proxima Nova", size: 12).weight(.semibold))
                .foregroundStyle(licenseSyncState.color)
                .onAppear {
                    updateSyncIconSpin()
                }
                .onChange(of: licenseSyncState) { _, _ in
                    updateSyncIconSpin()
                }
            }

            if let licenseSyncNotice, licenseSyncState == .failed {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    if licenseSyncNotice.preservesCachedData, let lastSuccessfulLicenseSyncDate {
                        Text("Last updated: \(formattedSyncDate(lastSuccessfulLicenseSyncDate))")
                            .font(.custom("Proxima Nova", size: 12))
                            .foregroundStyle(.white.opacity(0.58))
                    }

                    if licenseSyncNotice.canRetry {
                        Button(retryButtonTitle) {
                            retryLicenseSync()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .pointerCursor()
                        .disabled(isLicenseRefreshInFlight || licenseRetryCooldownRemaining > 0)
                    }

                    Text(licenseSyncNotice.userMessage)
                        .font(.custom("Proxima Nova", size: 13).weight(.medium))
                        .foregroundStyle(Color(red: 0.95, green: 0.43, blue: 0.40))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if activeLicenses.isEmpty {
                VStack(spacing: 14) {
                    Text("No active licenses")
                        .font(.custom("Proxima Nova", size: 14))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                LazyVGrid(columns: activeLicenseColumns, spacing: 12) {
                    ForEach(activeLicenses) { license in
                        Button {
                            selectedLicenseID = license.id
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Text(license.pluginName)
                                        .font(.custom("Proxima Nova", size: 15).weight(.semibold))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                        .truncationMode(.tail)

                                    if upgradedLicenseIDs.contains(license.id) {
                                        Text("Upgraded!")
                                            .font(.custom("Proxima Nova", size: 11).weight(.bold))
                                            .foregroundStyle(Color(red: 0.37, green: 0.88, blue: 0.63))
                                            .lineLimit(1)
                                            .transition(.scale.combined(with: .opacity))
                                    } else if license.edition == .demo {
                                        Text("Demo")
                                            .font(.custom("Proxima Nova", size: 11).weight(.semibold))
                                            .foregroundStyle(Color(red: 0.36, green: 0.68, blue: 0.98))
                                            .lineLimit(1)
                                    } else if license.edition == .trial {
                                        Text("Trial")
                                            .font(.custom("Proxima Nova", size: 11).weight(.semibold))
                                            .foregroundStyle(Color(red: 0.36, green: 0.68, blue: 0.98))
                                            .lineLimit(1)
                                    } else if license.edition == .beta {
                                        Text("Beta")
                                            .font(.custom("Proxima Nova", size: 11).weight(.semibold))
                                            .foregroundStyle(Color(red: 0.98, green: 0.72, blue: 0.28))
                                            .lineLimit(1)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .animation(.easeInOut(duration: 0.4), value: upgradedLicenseIDs)

                                Text(cardSecondaryText(for: license))
                                    .font(.custom("Proxima Nova", size: 12))
                                    .foregroundStyle(cardSecondaryColor(for: license))
                                    .lineLimit(1)
                                    .truncationMode(.tail)

                                HStack(spacing: 8) {
                                    Text("Version \(license.installedVersion ?? "--")")
                                        .font(.custom("Proxima Nova", size: 12).weight(.medium))
                                        .foregroundStyle(.white.opacity(0.88))
                                        .lineLimit(1)
                                        .truncationMode(.tail)

                                    if let availableVersion = license.availableVersion {
                                        Text("New: \(availableVersion)")
                                            .font(.custom("Proxima Nova", size: 12).weight(.semibold))
                                            .foregroundStyle(Color(red: 0.98, green: 0.72, blue: 0.28))
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(cardBackground(for: license))
                            .pointerCursor()
                        }
                        .buttonStyle(.plain)
                        .disabled(!installationStepStatuses.isEmpty)
                    }
                }
            }
        }
        .panelStyle()
    }

    private func statusPanel(for license: PluginLicenseItem) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 18) {
                statusBadge(for: license)

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Plugin")
                            .font(.custom("Proxima Nova", size: 12))
                            .foregroundStyle(.white.opacity(0.5))

                        HStack(spacing: 8) {
                            Text(license.pluginName)
                                .font(.custom("Proxima Nova", size: 16).weight(.medium))
                                .foregroundStyle(.white.opacity(0.95))
                                .textSelection(.enabled)

                            if upgradedLicenseIDs.contains(license.id) {
                                Text("Upgraded to Full!")
                                    .font(.custom("Proxima Nova", size: 13).weight(.bold))
                                    .foregroundStyle(Color(red: 0.37, green: 0.88, blue: 0.63))
                                    .transition(.scale.combined(with: .opacity))
                            } else if license.edition == .demo {
                                Text("Demo")
                                    .font(.custom("Proxima Nova", size: 13).weight(.semibold))
                                    .foregroundStyle(Color(red: 0.36, green: 0.68, blue: 0.98))
                            } else if license.edition == .trial {
                                Text("Trial")
                                    .font(.custom("Proxima Nova", size: 13).weight(.semibold))
                                    .foregroundStyle(Color(red: 0.36, green: 0.68, blue: 0.98))
                            } else if license.edition == .beta {
                                Text("Beta")
                                    .font(.custom("Proxima Nova", size: 13).weight(.semibold))
                                    .foregroundStyle(Color(red: 0.98, green: 0.72, blue: 0.28))
                            }
                        }
                        .animation(.easeInOut(duration: 0.4), value: upgradedLicenseIDs)
                    }

                    if license.lifecycleState == .activating {
                        installationProgressView
                    } else {
                        currentVersionRow(for: license)
                        dateRows(for: license)
                        if license.lifecycleState != .deactivating && license.lifecycleState != .suspended {
                            previousVersionsRow(for: license)
                        }
                    }
                }
            }

            if license.lifecycleState == .activating && installationFailed {
                HStack(spacing: 14) {
                    Button(action: retryInstallation) {
                        Text("Retry Installation")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .pointerCursor()

                    Button(action: dismissInstallationError) {
                        Text("Cancel")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .pointerCursor()
                }
            } else if license.lifecycleState == .suspended {
                suspendedSupportPanel(for: license)
            } else if license.lifecycleState != .activating {
                VStack(alignment: .leading, spacing: 12) {
                    if let deactivationErrorDetail, deactivationErrorLicenseID == license.id {
                        Text(deactivationErrorDetail)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Color(red: 0.95, green: 0.43, blue: 0.40).opacity(0.9))
                            .textSelection(.enabled)
                    }

                    if license.isRevoked {
                        HStack(spacing: 14) {
                            Link(destination: supportURL) {
                                Text("Online Support")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            .pointerCursor()
                            .disabled(isActivatingNewLicense)

                            Button(role: .destructive, action: removeSelectedLicense) {
                                Text("Remove Key")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            .pointerCursor()
                            .disabled(isActivatingNewLicense)
                        }
                    } else {
                        HStack(spacing: 14) {
                            if license.lifecycleState == .updateAvailable && license.hasInstalledPlugin {
                                Button(action: installUpdate) {
                                    Text("Update Available (\(license.availableVersion ?? "--"))")
                                        .fontWeight(.semibold)
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                                .pointerCursor()
                                .disabled(isActivatingNewLicense)
                            }

                            if license.lifecycleState == .deactivating, !license.isCorrupted {
                                Button(action: retryInstallation) {
                                    Text("Reactivate License")
                                        .fontWeight(.semibold)
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                                .pointerCursor()
                                .disabled(isActivatingNewLicense)
                            } else if license.isPluginMissing {
                                Button {
                                    if license.lifecycleState == .updateAvailable {
                                        installUpdate()
                                    } else {
                                        retryInstallation()
                                    }
                                } label: {
                                    Text("Reinstall Plugin")
                                        .fontWeight(.semibold)
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                                .pointerCursor()
                                .disabled(isActivatingNewLicense)
                            }

                            if license.lifecycleState == .deactivating || license.isCorrupted {
                                Button(role: .destructive, action: removeSelectedLicense) {
                                    Text("Remove Key")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.large)
                                .pointerCursor()
                                .disabled(isActivatingNewLicense)
                            } else {
                                Button {
                                    isShowingDeactivateConfirmation = true
                                } label: {
                                    Text("Deactivate License")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.large)
                                .pointerCursor()
                                .disabled(isActivatingNewLicense)
                            }

                            if license.hasInstalledPlugin {
                                Button(role: .destructive) {
                                    isShowingRemovePluginConfirmation = true
                                } label: {
                                    Text("Remove Plugin")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.large)
                                .pointerCursor()
                                .disabled(isActivatingNewLicense)
                            }
                        }
                    }
                }
            }
        }
        .panelStyle()
    }

    private func statusBadge(for license: PluginLicenseItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(statusTitle(for: license), systemImage: statusIcon(for: license))
                .font(.custom("Proxima Nova", size: 20).weight(.bold))
                .foregroundStyle(statusColor(for: license))

            Text(statusMessage(for: license))
                .font(.custom("Proxima Nova", size: 14))
                .foregroundStyle(.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)

            if let displayKey = license.activatedLicenseKey ?? license.lastKnownLicenseKey {
                VStack(alignment: .leading, spacing: 4) {
                    Text("License")
                        .font(.custom("Proxima Nova", size: 12))
                        .foregroundStyle(.white.opacity(0.5))

                    Text(displayKey)
                        .font(.custom("Proxima Nova", size: 13).weight(.medium))
                        .foregroundStyle(.white.opacity(0.92))
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 6)
            }

            if license.lifecycleState != .deactivating {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Activations")
                        .font(.custom("Proxima Nova", size: 12))
                        .foregroundStyle(.white.opacity(0.5))

                    Text(license.activationUsage)
                        .font(.custom("Proxima Nova", size: 13).weight(.medium))
                        .foregroundStyle(.white.opacity(0.92))
                }
                .padding(.top, 6)
            }

        }
        .padding(18)
        .frame(width: 245, alignment: .leading)
        .background(statusColor(for: license).opacity(0.12))
    }

    private func suspendedSupportPanel(for license: PluginLicenseItem) -> some View {
        HStack(spacing: 14) {
            Link(destination: supportURL) {
                Text("Online Support")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .pointerCursor()
        }
    }

    private func currentVersionRow(for license: PluginLicenseItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Current version")
                .font(.custom("Proxima Nova", size: 12))
                .foregroundStyle(.white.opacity(0.5))

            HStack(spacing: 10) {
                Text(license.installedVersion ?? "--")
                    .font(.custom("Proxima Nova", size: 16).weight(.medium))
                    .foregroundStyle(.white.opacity(0.95))

                if let availableVersion = license.availableVersion {
                    Text("New: \(availableVersion)")
                        .font(.custom("Proxima Nova", size: 14).weight(.semibold))
                        .foregroundStyle(statusColor(for: license))
                } else if license.installedVersion != nil && license.isInitialStatusLoad {
                    Text("Version up to date")
                        .font(.custom("Proxima Nova", size: 14).weight(.semibold))
                        .foregroundStyle(.green)
                }

                if let installationFeedback = license.installationFeedback {
                    Text(installationFeedback.message)
                        .font(.custom("Proxima Nova", size: 14).weight(.semibold))
                        .foregroundStyle(installationFeedback.color)
                }
            }
        }
    }

    private func previousVersionsRow(for license: PluginLicenseItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    togglePreviousVersions(for: license.id)
                } label: {
                    HStack {
                        Text("Previous versions")
                            .font(.custom("Proxima Nova", size: 15).weight(.medium))
                        Spacer()
                        Image(systemName: license.isShowingPreviousVersions ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(.white.opacity(0.06))
                    .pointerCursor()
                }
                .buttonStyle(.plain)

                if license.isShowingPreviousVersions {
                    VStack(spacing: 8) {
                        ForEach(filteredPreviousVersions(for: license), id: \.self) { info in
                            HStack(spacing: 8) {
                                Text("v\(info.version)")
                                    .font(.custom("Proxima Nova", size: 15).weight(.medium))
                                    .foregroundStyle(.white.opacity(0.92))

                                if info.isBeta {
                                    Text("beta")
                                        .font(.custom("Proxima Nova", size: 13).weight(.semibold))
                                        .foregroundStyle(Color(red: 0.98, green: 0.72, blue: 0.28))
                                } else if info.channel.lowercased() == "stable" {
                                    Text("stable")
                                        .font(.custom("Proxima Nova", size: 13).weight(.semibold))
                                        .foregroundStyle(Color(red: 0.37, green: 0.88, blue: 0.63))
                                }

                                Spacer()

                                Button("Install") {
                                    installPreviousVersion(info.version)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.large)
                                .pointerCursor()
                                .disabled(isActivatingNewLicense)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(.white.opacity(0.04))
                        }
                    }
                    .padding(.top, 10)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var isActivatingNewLicense: Bool {
        !installationStepStatuses.isEmpty
    }

    private var retryButtonTitle: String {
        licenseRetryCooldownRemaining > 0 ? "Retry in \(licenseRetryCooldownRemaining)s" : "Retry"
    }

    private var syncStatusIcon: String {
        switch licenseSyncState {
        case .idle:
            return "clock"
        case .syncing:
            return "arrow.triangle.2.circlepath"
        case .synced:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }

    private func updateSyncIconSpin() {
        if licenseSyncState == .syncing {
            withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                syncIconRotationDegrees = 360
            }
        } else {
            // A plain assignment here does not reliably interrupt the
            // in-flight `repeatForever` transaction above — the rotation
            // keeps looping under the old animation. An explicit zero-length
            // animation supersedes it, which snaps the angle back and stops
            // the repeat.
            withAnimation(.linear(duration: 0)) {
                syncIconRotationDegrees = 0
            }
        }
    }

    private var diagnosticsFingerprint: String {
        MachineFingerprint.generate()
    }

    // The raw hardware identifier used to be shown as-is (P68): a value
    // support could never search for, since the backoffice only ever stores
    // and displays fingerprint_hash = sha256(raw fingerprint), never the raw
    // value itself (appClient/src/utils/hash.ts). Showing the same hash's
    // prefix here — computed the identical way, over the identical string
    // this app already sends as the fingerprint — makes the two sides
    // comparable: support matches on "WHERE fingerprint_hash LIKE
    // '<prefix>%'" (backOffice/components/ActivationsSection.tsx slices the
    // same column to 12 chars). This matches what the backoffice shows for a
    // legacy/Cryptlex-routed activation; a NexKeyRuntime-routed one stores
    // its own machineBinding (SHA-512 truncated, tenant-scoped) in that same
    // column instead, which this app does not compute today — a real gap,
    // not silently glossed over (see PLANO_CONSOLIDADO.md, P68).
    private var diagnosticsFingerprintCopyValue: String {
        let digest = SHA256.hash(data: Data(diagnosticsFingerprint.utf8))
        return digest.prefix(6).map { String(format: "%02x", $0) }.joined()
    }

    private var appClientVersion: String {
        guard let url = Bundle.main.url(forResource: "VERSION", withExtension: nil),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return "unknown"
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func cardBackground(for license: PluginLicenseItem) -> Color {
        if selectedLicenseID == license.id {
            return .white.opacity(0.10)
        }

        return .white.opacity(0.04)
    }

    private func cardSecondaryText(for license: PluginLicenseItem) -> String {
        switch license.lifecycleState {
        case .suspended:
            return "License suspended"
        case _ where license.isPluginMissing:
            return "Plugin not installed"
        case .deactivating:
            if license.isCorrupted {
                return "Corrupted license"
            }
            if license.isRevoked {
                return "License unavailable"
            }
            return "License not active"
        default:
            return license.activatedLicenseKey ?? license.lastKnownLicenseKey ?? "--"
        }
    }

    private func cardSecondaryColor(for license: PluginLicenseItem) -> Color {
        switch license.lifecycleState {
        case .suspended:
            return Color(red: 0.98, green: 0.72, blue: 0.28)
        case _ where license.isPluginMissing:
            return Color(red: 0.98, green: 0.72, blue: 0.28)
        case .deactivating:
            return license.isCorrupted || license.isRevoked
                ? .red
                : Color(red: 0.98, green: 0.72, blue: 0.28)
        default:
            return .white.opacity(0.68)
        }
    }

    private func statusTitle(for license: PluginLicenseItem) -> String {
        switch license.lifecycleState {
        case .active:
            return license.isPluginMissing ? "Plugin not installed" : "Active"
        case .updateAvailable:
            return license.isPluginMissing ? "Plugin not installed" : "Update"
        case .suspended:
            return "Suspended"
        case .deactivating:
            if license.isCorrupted {
                return "License issue"
            }
            if license.isRevoked {
                return "License unavailable"
            }
            return "License not active"
        case .activating:
            return "Activating"
        case .idle:
            return "Not activated"
        }
    }

    private func statusMessage(for license: PluginLicenseItem) -> String {
        switch license.lifecycleState {
        case .active:
            return license.isPluginMissing ? "Run installation again." : "Plugin installed and unlocked."
        case .updateAvailable:
            return license.isPluginMissing ? "Run installation again." : "New version available."
        case .suspended:
            return "Contact support."
        case .deactivating:
            if license.isCorrupted {
                return "The saved license data cannot be used."
            }
            if license.isRevoked {
                return "This key is no longer valid."
            }
            return license.hasInstalledPlugin
                ? "The plugin is still installed."
                : "Run installation again."
        case .activating:
            return "Installing plugin..."
        case .idle:
            return "Enter your key to unlock the plugin."
        }
    }

    private func statusIcon(for state: PluginLifecycleState) -> String {
        switch state {
        case .active:
            return "checkmark.seal.fill"
        case .updateAvailable:
            return "arrow.down.circle.fill"
        case .suspended:
            return "exclamationmark.triangle.fill"
        case .deactivating:
            return "lock.open.fill"
        case .activating:
            return "hourglass.circle.fill"
        case .idle:
            return "key.fill"
        }
    }

    private func statusIcon(for license: PluginLicenseItem) -> String {
        if license.isPluginMissing {
            return "exclamationmark.triangle.fill"
        }

        return statusIcon(for: license.lifecycleState)
    }

    private func statusColor(for state: PluginLifecycleState) -> Color {
        switch state {
        case .active:
            return Color(red: 0.37, green: 0.88, blue: 0.63)
        case .updateAvailable:
            return Color(red: 0.98, green: 0.72, blue: 0.28)
        case .suspended:
            return Color(red: 0.98, green: 0.72, blue: 0.28)
        case .deactivating:
            return Color(red: 0.95, green: 0.43, blue: 0.40)
        case .activating:
            return Color(red: 0.36, green: 0.68, blue: 0.98)
        case .idle:
            return Color(red: 0.69, green: 0.76, blue: 0.88)
        }
    }

    private func statusColor(for license: PluginLicenseItem) -> Color {
        if license.isPluginMissing {
            return Color(red: 0.98, green: 0.72, blue: 0.28)
        }

        if license.lifecycleState == .deactivating {
            return license.isCorrupted || license.isRevoked
                ? Color(red: 0.95, green: 0.43, blue: 0.40)
                : Color(red: 0.98, green: 0.72, blue: 0.28)
        }

        return statusColor(for: license.lifecycleState)
    }

    private func statusRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.custom("Proxima Nova", size: 12))
                .foregroundStyle(.white.opacity(0.5))

            Text(value)
                .font(.custom("Proxima Nova", size: 16).weight(.medium))
                .foregroundStyle(.white.opacity(0.95))
                .textSelection(.enabled)
        }
    }

    private func dateRows(for license: PluginLicenseItem) -> some View {
        HStack(alignment: .top, spacing: 24) {
            statusRow(label: "Activation date", value: license.activationDate)
            statusRow(label: "Plugin update date", value: license.pluginUpdateDate)
            if license.lifecycleState == .deactivating, let deactivationDate = license.deactivationDate {
                statusRow(label: "Deactivation date", value: deactivationDate)
            }
        }
    }

    private func activatePlugin() {
        cancelBackgroundLicenseRefresh()
        activationErrorMessage = nil
        deactivationErrorDetail = nil
        deactivationErrorLicenseID = nil

        guard let selectedActivationProduct else {
            activationErrorMessage = AppMessages.text(.unexpectedError)
            return
        }

        let validation = workflowCoordinator.prepareActivationKeyOffline(
            licenseKey,
            product: selectedActivationProduct,
            existingLicenses: activeLicenses
        )

        guard case .success(let preparation) = validation else {
            if case .failure(let error) = validation {
                activationErrorMessage = error.displayMessage
            }
            return
        }

        preInstallSnapshot = nil
        let newLicenseID = beginInstallation(
            product: preparation.product,
            for: preparation.key,
            edition: preparation.edition,
            activationUsage: preparation.activationUsage
        )
        pendingTargetVersion = nil
        pendingActivateOnMachine = true
        pendingNewActivationLicenseID = newLicenseID
        installationTargetVersion = nil

        Task {
            let result = await runInstallationSteps(
                for: preparation.product,
                licenseKey: preparation.key,
                activateOnMachine: true,
                licenseID: newLicenseID
            )

            if let result {
                updateLicense(id: newLicenseID) { license in
                    license.lifecycleState = .active
                    license.isInitialStatusLoad = true
                    license.product = result.installedProduct
                    license.pluginName = result.installedProduct.displayName
                    license.pluginUpdateDate = currentTimestamp()
                    license.installedVersion = result.installedVersion
                    license.installedBundleNames = result.installedBundleNames
                    license.installationFeedback = .success(result.backendMessage?.message)
                    license.previousVersions = sortedReleases(
                        result.allReleases.filter { $0.version != result.installedVersion }
                    )
                }
                installationStepStatuses = [:]
                pendingNewActivationLicenseID = nil
                pendingTargetVersion = nil
                pendingActivateOnMachine = false
                installationTargetVersion = nil
                resetDownloadStats()
                clearTransientErrors()
                scrollToAnchor?(activeLicensesAnchorID)

                Task {
                    let updatedUsage = await fetchActivationUsage(for: preparation.key, product: result.installedProduct)
                    updateLicense(id: newLicenseID) { license in
                        license.activationUsage = updatedUsage
                    }
                }
            } else if !installationFailed {
                removeLicense(id: newLicenseID)
                pendingNewActivationLicenseID = nil
                pendingTargetVersion = nil
                pendingActivateOnMachine = false
                installationTargetVersion = nil
            }
        }
    }

    private func beginInstallation(
        product: AppProduct,
        for key: String,
        edition: LicenseEdition = .full,
        activationUsage: String = "--"
    ) -> UUID {
        let licenseID = UUID()
        let newLicense = PluginLicenseItem(
            id: licenseID,
            product: product,
            pluginName: product.displayName,
            edition: edition,
            installedVersion: nil,
            availableVersion: nil,
            activatedLicenseKey: key,
            lastKnownLicenseKey: key,
            activationDate: currentTimestamp(),
            pluginUpdateDate: currentTimestamp(),
            activationUsage: activationUsage,
            deactivationDate: nil,
            previousVersions: [],
            lifecycleState: .activating,
            isShowingPreviousVersions: false,
            isInitialStatusLoad: false,
            isRevoked: false,
            installationFeedback: nil,
            installedBundleNames: [],
            skipLocalActivation: false
        )

        activeLicenses.insert(newLicense, at: 0)
        selectedLicenseID = newLicense.id
        licenseKey = ""
        activationErrorMessage = nil
        deactivationErrorDetail = nil
        deactivationErrorLicenseID = nil
        isShowingActivationPanel = false
        actions.activate(key)
        return licenseID
    }

    private func resetDownloadStats() {
        downloadProgress = nil
        downloadBytesWritten = 0
        downloadBytesTotal = 0
        downloadBytesPerSecond = 0
        downloadLastSampleBytes = 0
        downloadLastSampleTime = nil
    }

    /// Updates the download UI state on every emission from the workflow
    /// coordinator. Speed is an EMA over instantaneous samples: smooth enough
    /// to feel stable, responsive enough that throttled connections show
    /// realistic numbers within ~1s.
    private func applyDownloadStats(_ stats: DownloadStats) {
        let now = Date()
        if let lastTime = downloadLastSampleTime {
            let dt = now.timeIntervalSince(lastTime)
            if dt >= 0.2 {
                let instant = Double(stats.bytesWritten - downloadLastSampleBytes) / dt
                downloadBytesPerSecond = downloadBytesPerSecond == 0
                    ? instant
                    : (downloadBytesPerSecond * 0.5 + instant * 0.5)
                downloadLastSampleBytes = stats.bytesWritten
                downloadLastSampleTime = now
            }
        } else {
            downloadLastSampleBytes = stats.bytesWritten
            downloadLastSampleTime = now
        }
        downloadBytesWritten = stats.bytesWritten
        downloadBytesTotal = stats.bytesTotal
        withAnimation(.linear(duration: 0.1)) {
            downloadProgress = stats.fraction
        }
    }

    private var downloadProgressText: String {
        guard downloadBytesWritten > 0 else {
            return "Preparing download... / \(formatBytes(downloadBytesTotal))"
        }

        return "\(formatBytes(downloadBytesWritten)) / \(formatBytes(downloadBytesTotal)) · \(formatSpeed(downloadBytesPerSecond))"
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        return formatter.string(fromByteCount: bytes)
    }

    private func formatSpeed(_ bytesPerSecond: Double) -> String {
        guard bytesPerSecond > 0 else { return "--" }
        return "\(formatBytes(Int64(bytesPerSecond)))/s"
    }

    private func runInstallationSteps(
        for product: AppProduct,
        targetVersion: String? = nil,
        licenseKey: String? = nil,
        activateOnMachine: Bool = false,
        licenseID: UUID? = nil
    ) async -> (installedProduct: AppProduct, installedVersion: String, installedBundleNames: [String], allReleases: [ReleaseVersionInfo], backendMessage: LicenseOperationMessage?)? {
        installationErrorDetail = nil
        installationFailed = false
        resetDownloadStats()

        let result = await workflowCoordinator.runInstallation(
            for: product,
            targetVersion: targetVersion,
            licenseKey: licenseKey,
            activateOnMachine: activateOnMachine,
            existingLicenses: activeLicenses
        ) { step, status, detail in
            withAnimation(.easeInOut(duration: 0.2)) {
                self.installationStepStatuses[step] = status
            }
            if let detail {
                self.installationErrorDetail = detail
            }
        } validatedLicense: { validationDetails in
            if let resolvedTargetVersion = targetVersion ?? validationDetails.releases.first(where: \.isCurrentPlatform)?.version {
                self.installationTargetVersion = resolvedTargetVersion
            }

            guard let licenseID else { return }
            self.updateLicense(id: licenseID) { license in
                license.product = validationDetails.product
                license.pluginName = validationDetails.product.displayName
                license.edition = validationDetails.edition
                license.activationUsage = validationDetails.activationUsage
                license.skipLocalActivation = validationDetails.skipLocalActivation
                license.runtime = validationDetails.runtime
                license.tenantId = validationDetails.tenantId
            }
        } downloadProgress: { stats in
            self.applyDownloadStats(stats)
        }

        switch result {
        case .success(let installedProduct, let installedVersion, let installedBundleNames, let allReleases, let message):
            return (
                installedProduct: installedProduct,
                installedVersion: installedVersion,
                installedBundleNames: installedBundleNames,
                allReleases: allReleases,
                backendMessage: message
            )
        case .failure(let detail):
            installationErrorDetail = detail
            installationFailed = true
            return nil
        }
    }

    private func fetchActivationUsage(for key: String, product: AppProduct) async -> String {
        await workflowCoordinator.fetchActivationUsage(for: key)
    }

    private func stepTextColor(for status: StepStatus) -> Color {
        switch status {
        case .pending:
            return .white.opacity(0.35)
        case .inProgress:
            return .white.opacity(0.95)
        case .completed:
            return .white.opacity(0.6)
        case .failed:
            return .white.opacity(0.95)
        }
    }

    private func dismissInstallationError() {
        let newActivationLicenseID = pendingNewActivationLicenseID
        installationFailed = false
        installationStepStatuses = [:]
        installationTargetVersion = nil
        pendingTargetVersion = nil
        pendingActivateOnMachine = false
        pendingNewActivationLicenseID = nil

        if let newActivationLicenseID, selectedLicenseID == newActivationLicenseID {
            removeLicense(id: newActivationLicenseID)
            preInstallSnapshot = nil
        } else if let snapshot = preInstallSnapshot {
            restoreLicense(snapshot)
            preInstallSnapshot = nil
        } else if let newActivationLicenseID {
            removeLicense(id: newActivationLicenseID)
            preInstallSnapshot = nil
        } else {
            updateSelectedLicense { license in
                license.lifecycleState = .deactivating
                license.availableVersion = nil
                license.deactivationDate = currentTimestamp()
            }
        }
    }

    /// Single-shot reset for every transient HTTP-related error banner shown
    /// to the user. Called whenever any backend request finishes successfully
    /// — the idea is that one happy response means whatever stale errors
    /// were on screen are no longer relevant, so the UI gets back to a clean
    /// state instead of forcing the user to dismiss each notice individually.
    /// `persistenceErrorMessage` is intentionally NOT cleared here: it
    /// represents a local disk/crypto failure unrelated to backend health
    /// and has its own lifecycle inside `saveLicenses`/`loadCachedLicensesFromStorage`.
    /// `installationFailed` is also left alone since it is a lifecycle flag,
    /// not an error message.
    private func clearTransientErrors() {
        activationErrorMessage = nil
        installationErrorDetail = nil
        deactivationErrorDetail = nil
        deactivationErrorLicenseID = nil
        licenseSyncNotice = nil
    }

    private func installUpdate() {
        guard let selectedLicense, selectedLicense.availableVersion != nil else {
            return
        }

        cancelBackgroundLicenseRefresh()
        let snapshot = selectedLicense
        preInstallSnapshot = snapshot
        deactivationErrorDetail = nil
        deactivationErrorLicenseID = nil

        updateSelectedLicense { license in
            license.lifecycleState = .activating
            license.installationFeedback = nil
            license.isShowingPreviousVersions = false
        }

        pendingTargetVersion = selectedLicense.availableVersion
        pendingActivateOnMachine = false
        installationTargetVersion = pendingTargetVersion

        Task {
            let result = await runInstallationSteps(
                for: selectedLicense.product,
                targetVersion: pendingTargetVersion,
                licenseKey: selectedLicense.lastKnownLicenseKey,
                activateOnMachine: false,
                // Passed so `validatedLicense` records `runtime`/`tenantId`
                // for THIS license. Without it the closure returns at its
                // `guard let licenseID`, and an update silently dropped the
                // runtime the response had just reported — leaving a NexKey
                // license looking legacy to `deactivateLicense`.
                licenseID: selectedLicense.id
            )

            if let result {
                preInstallSnapshot = nil
                pendingTargetVersion = nil
                installationTargetVersion = nil
                updateSelectedLicense { license in
                    license.isInitialStatusLoad = false
                    license.installedVersion = result.installedVersion
                    license.installedBundleNames = result.installedBundleNames
                    license.availableVersion = nil
                    license.previousVersions = sortedReleases(
                        result.allReleases.filter { $0.version != result.installedVersion }
                    )
                    license.activatedLicenseKey = license.lastKnownLicenseKey
                    license.pluginUpdateDate = currentTimestamp()
                    license.deactivationDate = nil
                    license.installationFeedback = .success(result.backendMessage?.message)
                    license.lifecycleState = .active
                }
                installationStepStatuses = [:]
                resetDownloadStats()
                clearTransientErrors()
            } else if !installationFailed {
                preInstallSnapshot = nil
                pendingTargetVersion = nil
                installationTargetVersion = nil
                restoreLicense(snapshot)
            }
        }
        actions.installUpdate()
    }

    private func installPreviousVersion(_ version: String) {
        guard let selectedLicense,
              !version.isEmpty,
              selectedLicense.installedVersion != version else {
            return
        }

        cancelBackgroundLicenseRefresh()
        let snapshot = selectedLicense
        preInstallSnapshot = snapshot
        pendingTargetVersion = version
        pendingActivateOnMachine = false
        installationTargetVersion = version
        deactivationErrorDetail = nil
        deactivationErrorLicenseID = nil

        updateSelectedLicense { license in
            license.lifecycleState = .activating
            license.installationFeedback = nil
            license.isShowingPreviousVersions = false
        }

        Task {
            let result = await runInstallationSteps(
                for: selectedLicense.product,
                targetVersion: version,
                licenseKey: selectedLicense.lastKnownLicenseKey,
                activateOnMachine: false,
                // Same reason as `installUpdate` above.
                licenseID: selectedLicense.id
            )

            if let result {
                preInstallSnapshot = nil
                pendingTargetVersion = nil
                installationTargetVersion = nil
                let latestKnownVersion = highestVersion(result.allReleases.map(\.version))

                updateSelectedLicense { license in
                    license.isInitialStatusLoad = false
                    license.installedVersion = result.installedVersion
                    license.installedBundleNames = result.installedBundleNames
                    license.previousVersions = sortedReleases(
                        result.allReleases.filter { $0.version != result.installedVersion }
                    )
                    license.activatedLicenseKey = license.lastKnownLicenseKey
                    license.pluginUpdateDate = currentTimestamp()
                    license.deactivationDate = nil
                    license.installationFeedback = .success(result.backendMessage?.message)
                    license.isShowingPreviousVersions = false

                    if result.installedVersion == latestKnownVersion {
                        license.availableVersion = nil
                        license.lifecycleState = .active
                    } else {
                        license.availableVersion = latestKnownVersion
                        license.lifecycleState = .updateAvailable
                    }
                }
                installationStepStatuses = [:]
                resetDownloadStats()
                clearTransientErrors()
            } else if !installationFailed {
                preInstallSnapshot = nil
                pendingTargetVersion = nil
                installationTargetVersion = nil
                restoreLicense(snapshot)
            }
        }
    }

    private func restoreLicense(_ snapshot: PluginLicenseItem) {
        guard let index = activeLicenses.firstIndex(where: { $0.id == snapshot.id }) else {
            return
        }
        activeLicenses[index] = snapshot
    }

    private func retryInstallation() {
        guard let selectedLicense, let key = selectedLicense.lastKnownLicenseKey else {
            return
        }

        cancelBackgroundLicenseRefresh()
        let isRetryingRevokedLicense = selectedLicense.isRevoked
        let isRetryingNewActivation = selectedLicense.id == pendingNewActivationLicenseID
        if !isRetryingNewActivation && preInstallSnapshot?.id != selectedLicense.id {
            preInstallSnapshot = selectedLicense
        }
        let retryBaseline = preInstallSnapshot?.id == selectedLicense.id ? preInstallSnapshot : selectedLicense

        installationFailed = false
        installationStepStatuses = [:]
        deactivationErrorDetail = nil
        deactivationErrorLicenseID = nil

        pendingActivateOnMachine = retryBaseline?.lifecycleState == .deactivating || isRetryingNewActivation
        if pendingActivateOnMachine {
            pendingTargetVersion = nil
        }
        installationTargetVersion = pendingTargetVersion

        updateSelectedLicense { license in
            license.lifecycleState = .activating
            if !isRetryingRevokedLicense {
                license.deactivationDate = nil
            }
            license.installationFeedback = nil
        }

        Task {
            let result = await runInstallationSteps(
                for: selectedLicense.product,
                targetVersion: pendingTargetVersion,
                licenseKey: key,
                activateOnMachine: pendingActivateOnMachine,
                licenseID: selectedLicense.id
            )

            if let result {
                preInstallSnapshot = nil
                if isRetryingNewActivation {
                    pendingNewActivationLicenseID = nil
                }
                pendingTargetVersion = nil
                pendingActivateOnMachine = false
                installationTargetVersion = nil
                let latestKnownVersion = highestVersion(result.allReleases.map(\.version))

                updateLicense(id: selectedLicense.id) { license in
                    license.isInitialStatusLoad = true
                    license.product = result.installedProduct
                    license.pluginName = result.installedProduct.displayName
                    license.pluginUpdateDate = currentTimestamp()
                    license.activatedLicenseKey = key
                    license.installedVersion = result.installedVersion
                    license.installedBundleNames = result.installedBundleNames
                    license.isRevoked = false
                    license.deactivationDate = nil
                    license.installationFeedback = .success(result.backendMessage?.message)
                    license.previousVersions = sortedReleases(
                        result.allReleases.filter { $0.version != result.installedVersion }
                    )

                    if result.installedVersion == latestKnownVersion {
                        license.availableVersion = nil
                        license.lifecycleState = .active
                    } else {
                        license.availableVersion = latestKnownVersion
                        license.lifecycleState = .updateAvailable
                    }
                }
                installationStepStatuses = [:]
                resetDownloadStats()
                clearTransientErrors()
                scrollToAnchor?(activeLicensesAnchorID)

                Task {
                    let updatedUsage = await fetchActivationUsage(for: key, product: result.installedProduct)
                    updateLicense(id: selectedLicense.id) { license in
                        license.activationUsage = updatedUsage
                    }
                }
            } else if !installationFailed {
                preInstallSnapshot = nil
                pendingTargetVersion = nil
                pendingActivateOnMachine = false
                installationTargetVersion = nil
                if isRetryingNewActivation {
                    removeLicense(id: selectedLicense.id)
                    pendingNewActivationLicenseID = nil
                } else {
                    updateLicense(id: selectedLicense.id) { license in
                        license.lifecycleState = .deactivating
                        license.deactivationDate = currentTimestamp()
                    }
                }
            }
        }
    }

    private func removeSelectedLicense() {
        guard let selectedLicense else {
            return
        }

        cancelBackgroundLicenseRefresh()
        removeLicense(id: selectedLicense.id)
    }

    private func removeSuspendedSelectedLicense() {
        guard let selectedLicense else {
            return
        }

        cancelBackgroundLicenseRefresh()
        let licenseID = selectedLicense.id
        deactivationErrorDetail = nil
        deactivationErrorLicenseID = nil

        Task {
            let result = await workflowCoordinator.deactivateLicense(for: selectedLicense)

            switch result {
            case .success:
                removeLicense(id: licenseID)
                actions.deactivate()
            case .failure(let detail):
                deactivationErrorDetail = detail
                deactivationErrorLicenseID = licenseID
            }
        }
    }

    private func removeLicense(id: UUID) {
        activeLicenses.removeAll { $0.id == id }

        if let currentSelectionID = selectedLicenseID,
           currentSelectionID != id,
           activeLicenses.contains(where: { $0.id == currentSelectionID }) {
            return
        }

        selectedLicenseID = activeLicenses.first?.id

        if activeLicenses.isEmpty {
            isShowingActivationPanel = true
        }
    }

    private func removePlugin() {
        guard let selectedLicense, !selectedLicense.installedBundleNames.isEmpty else {
            return
        }

        cancelBackgroundLicenseRefresh()
        let licenseID = selectedLicense.id
        let wasDeactivated = selectedLicense.lifecycleState == .deactivating
        let wasRevoked = selectedLicense.isRevoked

        Task {
            let result = await workflowCoordinator.uninstallPluginBundles(for: selectedLicense)

            switch result {
            case .success:
                clearTransientErrors()

                updateLicense(id: licenseID) { license in
                    license.installedBundleNames = []
                    license.installedVersion = nil
                    license.availableVersion = nil
                    license.previousVersions = []
                    license.isShowingPreviousVersions = false
                    license.installationFeedback = .warning("Plugin removed. Your license was not cancelled.")
                    if wasDeactivated || wasRevoked {
                        license.lifecycleState = .deactivating
                    } else if license.lifecycleState == .updateAvailable {
                        license.lifecycleState = .active
                    }
                    if wasDeactivated {
                        license.deactivationDate = currentTimestamp()
                    }
                }
                actions.removePlugin()
            case .failure(let error):
                deactivationErrorDetail = error.displayMessage
                deactivationErrorLicenseID = licenseID
            }
        }
    }

    private func deactivatePlugin() {
        guard let selectedLicense else {
            return
        }

        cancelBackgroundLicenseRefresh()
        let licenseID = selectedLicense.id

        Task {
            let result = await workflowCoordinator.deactivateLicense(for: selectedLicense)

            switch result {
            case .success(let updatedUsage):
                updateLicense(id: licenseID) { license in
                    license.lifecycleState = .deactivating
                    license.isInitialStatusLoad = false
                    license.availableVersion = nil
                    license.activationUsage = updatedUsage
                    license.activatedLicenseKey = nil
                    license.deactivationDate = currentTimestamp()
                    license.isShowingPreviousVersions = false
                    license.installationFeedback = .warning("Plugin files were not removed.")
                }
                clearTransientErrors()

                actions.deactivate()
            case .failure(let detail):
                deactivationErrorDetail = detail
                deactivationErrorLicenseID = licenseID
            }
        }
    }

    private func togglePreviousVersions(for id: UUID) {
        for index in activeLicenses.indices {
            activeLicenses[index].isShowingPreviousVersions = activeLicenses[index].id == id ? !activeLicenses[index].isShowingPreviousVersions : false
        }
    }

    private func updateSelectedLicense(_ mutation: (inout PluginLicenseItem) -> Void) {
        guard let selectedLicenseID else {
            return
        }

        updateLicense(id: selectedLicenseID, mutation)
    }

    private func updateLicense(id: UUID, _ mutation: (inout PluginLicenseItem) -> Void) {
        guard let index = activeLicenses.firstIndex(where: { $0.id == id }) else {
            return
        }

        mutation(&activeLicenses[index])
    }

    private func sortedVersions(_ versions: [String]) -> [String] {
        workflowCoordinator.sortedVersions(versions)
    }

    private func sortedReleases(_ releases: [ReleaseVersionInfo]) -> [ReleaseVersionInfo] {
        workflowCoordinator.sortedReleases(releases)
    }

    private func filteredPreviousVersions(for license: PluginLicenseItem) -> [ReleaseVersionInfo] {
        let latestKnownVersion = highestVersion(
            [license.installedVersion, license.availableVersion]
                .compactMap { $0 } + license.previousVersions.map(\.version)
        )

        let maxPreviousVersions = 5

        var seen: Set<String> = []
        let deduped = license.previousVersions.filter { info in
            guard seen.insert(info.version).inserted else { return false }
            return true
        }

        return Array(sortedReleases(deduped).filter { info in
            if info.version == license.installedVersion {
                return false
            }

            if info.version == latestKnownVersion {
                return false
            }

            return true
        }.prefix(maxPreviousVersions))
    }

    private func highestVersion(_ versions: [String]) -> String? {
        workflowCoordinator.highestVersion(in: versions)
    }

    private func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        workflowCoordinator.compareVersions(lhs, rhs)
    }

    private func currentTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "dd/MM/yyyy HH:mm:ss"
        return formatter.string(from: Date())
    }

    private func formattedSyncDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter.string(from: date)
    }

    private func retryLicenseSync() {
        guard licenseRetryCooldownRemaining == 0 else {
            return
        }

        licenseRetryCooldownRemaining = 30
        startBackgroundLicenseRefresh(force: true)
        Task {
            await runLicenseRetryCooldown()
        }
    }

    private func runLicenseRetryCooldown() async {
        while licenseRetryCooldownRemaining > 0 {
            try? await Task.sleep(for: .seconds(1))
            licenseRetryCooldownRemaining -= 1
        }
    }

    private func startBackgroundLicenseRefresh(force: Bool = false) {
        guard !isActivatingNewLicense, installationStepStatuses.isEmpty else { return }
        guard licenseRefreshTask == nil else { return }

        licenseRefreshTask = Task {
            await refreshLicensesInBackground(force: force)
            licenseRefreshTask = nil
        }
    }

    private func cancelBackgroundLicenseRefresh() {
        licenseRefreshTask?.cancel()
        licenseRefreshTask = nil

        if licenseSyncState == .syncing {
            licenseSyncState = .idle
        }
    }

    // MARK: - Persistence

    private func saveLicenses() {
        do {
            try workflowCoordinator.saveLicenses(activeLicenses)
            persistenceErrorMessage = nil
        } catch {
            persistenceErrorMessage = "Could not save license data securely. \(error.localizedDescription)"
        }
    }

    private func reconcileLocalLicenseState() async {
        guard !activeLicenses.isEmpty else { return }
        activeLicenses = await workflowCoordinator.reconcileLocalLicenseState(activeLicenses)
    }

    private func loadCachedLicensesFromStorage() {
        let cached: [PluginLicenseItem]
        do {
            cached = try workflowCoordinator.loadCachedLicenses()
            persistenceErrorMessage = nil
        } catch {
            activeLicenses = []
            selectedLicenseID = nil
            licenseSyncState = .failed
            licenseSyncNotice = nil
            persistenceErrorMessage = "Could not load saved license data. \(error.localizedDescription)"
            isShowingActivationPanel = true
            return
        }

        let currentSelectionID = selectedLicenseID
        activeLicenses = cached

        if let currentSelectionID,
           cached.contains(where: { $0.id == currentSelectionID }) {
            selectedLicenseID = currentSelectionID
        } else {
            selectedLicenseID = cached.first?.id
        }

        licenseSyncState = cached.isEmpty ? .idle : .syncing
        licenseSyncNotice = nil

        if cached.isEmpty {
            isShowingActivationPanel = true
        }
    }

    private func refreshLicensesInBackground(force: Bool = false) async {
        let now = Date()
        guard !isLicenseRefreshInFlight else {
            return
        }
        if !force,
           let lastAttempt = lastLicenseRefreshAttemptDate,
           now.timeIntervalSince(lastAttempt) < Self.minimumBackendRefreshInterval {
            return
        }

        let initialSnapshot = activeLicenses
        guard !initialSnapshot.isEmpty else {
            licenseSyncState = .idle
            licenseSyncNotice = nil
            return
        }

        isLicenseRefreshInFlight = true
        lastLicenseRefreshAttemptDate = now
        defer {
            isLicenseRefreshInFlight = false
        }

        licenseSyncState = .syncing
        licenseSyncNotice = nil
        rotateHeaderHeadline()

        // Catch out-of-band deletion of the `.dat` credential file between
        // app launches and inside a single session, so the user lands on the
        // recovery panel without having to relaunch.
        let cachedSnapshot = await workflowCoordinator.reconcileLocalLicenseState(initialSnapshot)
        guard !Task.isCancelled else { return }

        if cachedSnapshot != initialSnapshot {
            activeLicenses = cachedSnapshot
        }

        let selectionAtRefreshStartID = selectedLicenseID
        let refreshResult = await workflowCoordinator.refreshLicenses(
            cachedSnapshot,
            allowsBackendSync: true
        )
        guard !Task.isCancelled else { return }

        let refreshed: [PluginLicenseItem]

        switch refreshResult {
        case .success(let licenses):
            refreshed = licenses
            licenseSyncState = .synced
            lastSuccessfulLicenseSyncDate = Date()
            licenseRetryCooldownRemaining = 0
            clearTransientErrors()
        case .fallback(let licenses, let notice):
            refreshed = licenses
            licenseSyncState = .failed
            licenseSyncNotice = notice
        }

        var newUpgrades: Set<UUID> = []
        for refreshedLicense in refreshed {
            if let old = cachedSnapshot.first(where: { $0.id == refreshedLicense.id }),
               (old.edition == .demo || old.edition == .trial), refreshedLicense.edition == .full {
                newUpgrades.insert(refreshedLicense.id)
            }
        }

        let currentSelectionID = selectedLicenseID
        let merged = mergeRefreshResult(
            refreshed: refreshed,
            snapshot: cachedSnapshot,
            current: activeLicenses
        )
        activeLicenses = merged

        if !newUpgrades.isEmpty {
            upgradedLicenseIDs = newUpgrades
            Task {
                try? await Task.sleep(for: .seconds(5))
                upgradedLicenseIDs = []
            }
        }

        if let currentSelectionID,
           merged.contains(where: { $0.id == currentSelectionID }) {
            selectedLicenseID = currentSelectionID
        } else if let selectionAtRefreshStartID,
                  merged.contains(where: { $0.id == selectionAtRefreshStartID }) {
            selectedLicenseID = selectionAtRefreshStartID
        } else {
            selectedLicenseID = merged.first?.id
        }
    }

    private func refreshLicensesFromSDKSilently() async {
        let initial = activeLicenses
        guard !initial.isEmpty else { return }
        if isActivatingNewLicense || !installationStepStatuses.isEmpty { return }

        // Reconcile first so the SDK poll never hits Cryptlex with a key whose
        // local credential file was wiped between cycles. Licenses that flip
        // to `.deactivating` are skipped by `refreshFromSDKOnly` (eligibility
        // guard) and by the backend sync (it skips `.deactivating` entries).
        let snapshot = await workflowCoordinator.reconcileLocalLicenseState(initial)
        if snapshot != initial {
            activeLicenses = snapshot
        }

        let (refreshed, changedKeys) = await workflowCoordinator.refreshFromSDKOnly(snapshot)

        // Beta licenses use skipLocalActivation, so the SDK has no local
        // record and the fast poll above can't detect remote state changes
        // (suspend/revoke). The backend is the only authoritative source
        // for them — escalate on every cycle so their status converges in
        // ~2 min instead of waiting for the 15-min heartbeat.
        let hasBackendOnlyLicenses = snapshot.contains {
            $0.edition == .beta
                && $0.lifecycleState != .deactivating
                && !$0.isRevoked
        }

        guard !changedKeys.isEmpty || hasBackendOnlyLicenses else { return }

        // Apply the SDK-detected downgrades immediately for snappy UI.
        activeLicenses = mergeRefreshResult(
            refreshed: refreshed,
            snapshot: snapshot,
            current: activeLicenses
        )

        // Escalate to a full backend refresh so the authoritative domain
        // status (revoked vs suspended) and the latest release/message
        // payload land in UI right after. One batch call covers all keys.
        startBackgroundLicenseRefresh(force: !changedKeys.isEmpty)
    }

    private func startBackgroundRefreshTimers() {
        if sdkPollingTask == nil {
            sdkPollingTask = Task {
                // Fire immediately: foreground reactivation should reflect a
                // remotely-revoked key in seconds, not after the next interval.
                await refreshLicensesFromSDKSilently()
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(120))
                    if Task.isCancelled { break }
                    await refreshLicensesFromSDKSilently()
                }
            }
        }

        if backendHeartbeatTask == nil {
            backendHeartbeatTask = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(900))
                    if Task.isCancelled { break }
                    if isActivatingNewLicense || !installationStepStatuses.isEmpty { continue }
                    startBackgroundLicenseRefresh()
                    await checkForAppUpdate()
                }
            }
        }
    }

    private func stopBackgroundRefreshTimers() {
        sdkPollingTask?.cancel()
        sdkPollingTask = nil
        backendHeartbeatTask?.cancel()
        backendHeartbeatTask = nil
        cancelBackgroundLicenseRefresh()
    }

    /// Polls the backend for the latest published client release and shows
    /// the banner only when the remote version is strictly newer than the
    /// installed one and the user has not dismissed that exact version in
    /// this session. Silent on every failure — the banner must never appear
    /// because of a network blip.
    private func checkForAppUpdate() async {
        guard let latest = await workflowCoordinator.fetchLatestApp() else { return }
        let current = appClientVersion
        guard workflowCoordinator.compareVersions(latest.version, current) == .orderedDescending else {
            pendingAppUpdate = nil
            return
        }
        if dismissedAppUpdateVersion == latest.version { return }
        pendingAppUpdate = AppUpdateInfo(
            version: latest.version,
            downloadURL: latest.downloadURL,
            releaseNotes: nil
        )
    }

    private func mergeRefreshResult(
        refreshed: [PluginLicenseItem],
        snapshot: [PluginLicenseItem],
        current: [PluginLicenseItem]
    ) -> [PluginLicenseItem] {
        let refreshedByID = Dictionary(uniqueKeysWithValues: refreshed.map { ($0.id, $0) })
        let snapshotByID = Dictionary(uniqueKeysWithValues: snapshot.map { ($0.id, $0) })
        let snapshotIDs = Set(snapshot.map(\.id))

        return current.compactMap { currentLicense in
            guard snapshotIDs.contains(currentLicense.id) else {
                return currentLicense
            }

            guard let refreshedLicense = refreshedByID[currentLicense.id] else {
                return nil
            }

            guard let snapshotLicense = snapshotByID[currentLicense.id] else {
                return refreshedLicense
            }

            if currentLicense != snapshotLicense,
               shouldPreserveLocalChange(current: currentLicense, snapshot: snapshotLicense) {
                return currentLicense
            }

            return refreshedLicense
        }
    }

    private func shouldPreserveLocalChange(current: PluginLicenseItem, snapshot: PluginLicenseItem) -> Bool {
        if current.lifecycleState == .deactivating, snapshot.lifecycleState != .deactivating {
            return true
        }

        if current.lifecycleState == .activating, snapshot.lifecycleState != .activating {
            return true
        }

        if current.activatedLicenseKey != snapshot.activatedLicenseKey
            || current.installedVersion != snapshot.installedVersion
            || current.availableVersion != snapshot.availableVersion
            || current.deactivationDate != snapshot.deactivationDate
            || current.isRevoked != snapshot.isRevoked {
            return true
        }

        return false
    }

    private func copyDiagnostics() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(diagnosticsFingerprintCopyValue, forType: .string)
        #endif
    }

}

private extension View {
    func panelStyle() -> some View {
        self
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.04))
    }

    func pointerCursor() -> some View {
        #if os(macOS)
        self
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
        #else
        self
        #endif
    }
}

#if DEBUG
#Preview("Active Licenses") {
    ContentView()
}
#endif
