# Changelog — MCNexus Apps (macOS & Windows)

All notable changes to the **MCNexus** client applications for macOS and Windows are documented in this file.

---

## [0.7.9] - Unreleased

### Fixed
- **Strict SemVer Precedence (macOS & Windows)**: Replaced naive numeric segment parsing with a structured SemVer parser (`parseSemver` / `ParsedSemver`). Final stable releases (e.g., `1.14`) now hold strict precedence over prerelease/beta builds (e.g., `1.14-beta.1`), preventing erroneous downgrade prompts for users with beta edition access.
- **GitHub Rate Limit Handling**: Immediately reset rate limit cooldown timers when the user triggers a manual retry, and improved user-facing error messages with remaining time before reset.
- **Release Service Resiliency**: Handled `release_service_unavailable` errors by prioritizing informative backend error messages over generic local errors.

### Added
- **Obsolete Bundle Cleanup**: Automatically remove legacy and version-suffixed plugin directories during new installations on macOS and Windows to prevent orphaned artifacts.
- **Beta Channel Filtering by License Edition**: Exclude prerelease/beta channels for non-beta license editions, ensuring only authorized clients receive beta release listings.

---

## [0.7.8] - 2026-10-11

### Added
- **NexKeyRuntime SDK Integration**: Native support for local license synchronization and validation via `NexKeyRuntime` across macOS and Windows.
- **Activation Usage Tracking**: Display license activation slot count (`activationUsage`) in the client UI.
- **Flexible Adoption and Deactivation**: Support for product variants and license key parameters during NexKey runtime deactivation and adoption workflows.

### Changed
- **Non-blocking Synchronization**: Streamlined license sync by eliminating redundant blocking network calls and activation checks.
- **Validation Resiliency**: Graceful fallback to locally cached release metadata if the backend release service is transiently unavailable.
- **Installation Persistence on Activation Failure**: Retain installed plugin files instead of performing a destructive rollback if subsequent activation checks encounter transient errors.

### Fixed
- Gracefully handle empty or placeholder (`--`) activation usage values.
- Use canonical `PluginName` for product name resolution across plugin licenses.

---

## [0.7.2] - 2026-10-06

### Added
- **Interrupted Installation Recovery**: Support for resuming and recovering downloads and installations interrupted by network disconnections.
- **NexKey Runtime Scope Configuration**: Support for configuring user-level vs. system-level runtime scope.

---

## [0.7.1] - 2026-10-04

### Added
- **Enhanced Deep Link Support (`mcnexus://`)**: Direct product activation and license onboarding from browsers and external links.
- **Single-Instance Application Control**: Prevent multiple concurrent application instances, bringing the active instance window to the foreground (`ForceForeground`).
- **SHA-256 Download Integrity Verification**: Verify SHA-256 checksums before unpacking release archives.
- **NexKeyRuntime SDK Update**: Upgraded the shared runtime SDK to version 1.0.1.

---

## [0.7.0] - 2026-09-28

### Added
- **Demo, Trial, and Beta Edition Support**: Full license lifecycle support for demo, trial, and early access editions.
- **NexKeyRuntime Windows Integration**: Initial Windows routing and native integration for the NexKey licensing provider.
- **Code Signing**: Digital signing of the `NexKeyRuntime` shared library to prevent operating system security alerts.
- **Visual Sync Indicator**: Rotating sync status icon in `ContentView` header during active backend synchronization.

---

## [0.1.13-mac] / [0.1.6-win] - 2026-09-08

### Added
- **Batch Sync Processing (`sync-batch`)**: Group concurrent license checks into single HTTP requests to reduce network overhead.
- **Unified Activation Messaging**: Standardized error messages and machine activation feedback across macOS and Windows.
- **Active Licenses Grid**: Improved UI layout for displaying active licenses with proper text truncation.
