# Changelog — MCNexus Apps (macOS & Windows)

All notable changes to the **MCNexus** client applications for macOS and Windows are documented in this file.

---

## [Unreleased]

### Fixed
- **Deactivation Limit Feedback & State Preservation (macOS & Windows):** Added a clear message when a license reaches its deactivation limit and ensured failed or rejected deactivations preserve the active license state on both macOS and Windows (preventing premature UI state transitions and reentrant clicks on Windows, and resetting cached activation usage counters on macOS upon successful deactivation).

---

## [0.7.14] - 2026-11-24

### Added
- **Per-Device MIDI Port Selection (macOS & Windows):** Added interactive MIDI device toggles in the macOS menu bar and Windows system tray with saved per-device preferences, letting you enable or release individual controllers on demand so MCNexus coexists cleanly with other MIDI apps.
- **First-Launch Compatible Controller Auto-Selection (macOS & Windows):** On first launch, MCNexus automatically enables the first available supported or custom MIDI controller. Any manual changes are preserved on future launches.
- **Generic Encoder Mode Selector & Live Binding Diagnostics (macOS & Windows):** Added a **Generic Encoder Mode** submenu (`Auto-Detect` default, `Absolute (0-127)`, `Two's Complement`, `Binary Offset 64`, `Sign-Magnitude / Mackie`) with preferences saved automatically across launches, and expanded **Knob Activity** to display channel, bank, and encoder mode (including unmatched MIDI events and click actions).

### Fixed
- **MIDI Device List Visibility & Busy Port State (macOS & Windows):** Kept detected MIDI controllers visible in the menu bar and system tray even when no device is active, and clearly indicates when a device is busy because another app is already using it.
- **Live Diagnostics & Windows Tray Submenu Reliability (macOS & Windows):** Fixed **Knob Activity** not updating for unmatched MIDI inputs, removed placeholder encoder mode labels on button clicks, and fixed 64-bit Windows system tray submenu and live telemetry reliability.

---

## [0.7.13] - 2026-11-23

### Changed
- **Update Deep Link Routing (macOS & Windows):** Improved `mcnexus://updates/` deep link handling with tenant and product-variant resolution, and guarded license selection safely when background operations are busy.
- **Installer & Shutdown Reliability (Windows):** Improved clean application shutdown during installer upgrades, window close actions, and Windows session logoff/restart, and broadened native runtime library discovery across packaging modes.
- **Bundle & IPC Hardening (macOS & Windows):** Strengthened `.ofx` bundle path validation during installation on macOS and tightened local single-instance IPC access controls on Windows.

### Fixed
- **License List Stability During Sync (macOS & Windows):** Stabilized license enumeration during background synchronization cycles to prevent UI inconsistencies.

---

## [0.7.12] - 2026-11-16

### Added
- **NexControl MIDI Hardware Support (macOS & Windows):** Added MIDI hardware support across both platforms with live connection diagnostics, hardware profile reloading, and hub pause/resume controls in the Windows system tray and macOS menu bar.
- **Native Menu Bar Controls (macOS):** Added a direct **Open MCNexus** action and live MIDI connection/activity status icon in the macOS menu bar.
- **Automatic Network Recovery Monitoring:** Added passive network availability detection across macOS and Windows that waits for connections to stabilize after reconnecting before refreshing licenses, preventing burst requests on unstable networks.
- **Offline Tolerance Expiry Warning & Safe Manual Retry:** Added a clear warning state with an immediate retry option when a license's offline validity window expires, with fast timeout handling on manual retries so failed sync attempts never discard locally saved license state.

### Changed
- **Quiet Background Synchronization & Resource Efficiency:** Reduced background CPU and network usage by spacing out routine checks while open, letting the embedded runtime handle its own scheduled renewals, and automatically pausing background timers when minimized to the system tray or menu bar. Lookup supports both user-level and system-level license storage on macOS and Windows.
- **Instant Window Restore:** Opening or restoring the application window from the tray or menu bar displays license status immediately without blocking the interface behind loading screens.
- **License Credential Handling:** Improved consistency when validating locally saved license formats during synchronization cycles.

### Fixed
- **Host Playback Performance (DaVinci Resolve / NLE):** Eliminated background licensing pauses during active playback, preventing frame drops and UI stutter in host editing applications.
- **System Tray & Menu Bar Responsiveness (macOS & Windows):** Fixed UI stutter when rapidly minimizing and restoring the Windows system tray window and eliminated menu lag in the macOS menu bar during active MIDI traffic.
- **Previous-Versions Ordering on Windows:** Aligned the Windows rollback version list with full semantic versioning rules so prerelease builds never appear above final stable releases.
- **Background License Check Reliability:** Resolved an issue where standard licenses could trigger unnecessary full re-synchronization requests during routine background checks.

---

## [0.7.11] - 2026-11-07

### Fixed
- **Multi-Variant Product Activation:** Resolved an issue where plugins with multiple editions or variants (such as Film Lab) could fail to activate properly after being licensed.
- **License Synchronization:** Improved manual and background license refresh to reliably restore active licensing status.
- **Independent Product Management:** Enhanced deactivation workflows to ensure removing a license cleanly targets the selected product edition without affecting sibling tools.
- **Product Configuration Isolation:** Improved settings separation between product editions to ensure independent operation across all installed tools.

---

## [0.7.10] - 2026-11-03

### Fixed
- **Multi-Product License Isolation:** Upgraded embedded `NexKeyRuntime` to version 1.2.1. Resolved an issue where activating or deactivating multiple products under the same tenant could cause license key collisions.
- **Product Deactivation Integrity:** Deactivating a product now cleanly and exclusively removes the license for that specific product, preserving active licenses across all other installed products.

---

## [0.7.9] - 2026-10-28

### Fixed
- **Strict SemVer Precedence (macOS & Windows):** Replaced naive numeric segment comparison with structured semantic versioning. Final stable releases (e.g., `1.14`) now hold strict precedence over prerelease/beta builds (e.g., `1.14-beta.1`), preventing erroneous downgrade prompts for users with beta edition access.
- **GitHub Rate Limit Handling:** Immediately reset rate limit cooldown timers when the user triggers a manual retry, and improved user-facing error messages with remaining time before reset.
- **Release Service Resiliency:** Handled temporary release service unavailability errors by prioritizing informative backend error messages over generic local errors.

### Added
- **Obsolete Bundle Cleanup:** Automatically remove legacy and version-suffixed plugin directories during new installations on macOS and Windows to prevent orphaned artifacts.
- **Beta Channel Filtering by License Edition:** Exclude prerelease/beta channels for non-beta license editions, ensuring only authorized clients receive beta release listings.

---

## [0.7.8] - 2026-10-11

### Added
- **NexKeyRuntime SDK Integration:** Native support for local license synchronization and validation via `NexKeyRuntime` across macOS and Windows.
- **Activation Usage Tracking:** Display license activation seat counts in the client UI.
- **Flexible Adoption and Deactivation:** Support for product variants and license key parameters during runtime deactivation and adoption workflows.

### Changed
- **Non-blocking Synchronization:** Streamlined license sync by eliminating redundant blocking network calls and activation checks.
- **Validation Resiliency:** Graceful fallback to locally cached release metadata if the backend release service is transiently unavailable.
- **Installation Persistence on Activation Failure:** Retain installed plugin files instead of performing a destructive rollback if subsequent activation checks encounter transient errors.

### Fixed
- Gracefully handle empty or placeholder activation usage values.
- Use canonical product naming consistently across plugin licenses.

---

## [0.7.2] - 2026-10-06

### Added
- **Interrupted Installation Recovery:** Support for resuming and recovering downloads and installations interrupted by network disconnections.
- **NexKey Runtime Scope Configuration:** Support for configuring user-level vs. system-level runtime scope.

---

## [0.7.1] - 2026-10-04

### Added
- **Enhanced Deep Link Support (`mcnexus://`):** Direct product activation and license onboarding from browsers and external links.
- **Single-Instance Application Control:** Prevent multiple concurrent application instances, bringing the active instance window to the foreground automatically.
- **SHA-256 Download Integrity Verification:** Verify SHA-256 checksums before unpacking release archives.
- **NexKeyRuntime SDK Update:** Upgraded the shared runtime SDK to version 1.0.1.

---

## [0.7.0] - 2026-09-28

### Added
- **Demo, Trial, and Beta Edition Support:** Full license lifecycle support for demo, trial, and early access editions.
- **NexKeyRuntime Windows Integration:** Initial Windows routing and native integration for the NexKey licensing provider.
- **Code Signing:** Digital signing of the `NexKeyRuntime` shared library to prevent operating system security alerts.
- **Visual Sync Indicator:** Rotating sync status icon in the application header during active backend synchronization.

---

## [0.1.13-mac] / [0.1.6-win] - 2026-09-08

### Added
- **Batch Sync Processing:** Group concurrent license checks into single requests to reduce network overhead.
- **Unified Activation Messaging:** Standardized error messages and machine activation feedback across macOS and Windows.
- **Active Licenses Grid:** Improved UI layout for displaying active licenses with proper text truncation.
