# Nexus Roadmap

[English](ROADMAP.md) · [Português](../pt-BR/docs/ROADMAP.md)

[Home](../README.md) · [Discovery](DISCOVERY.md) · [User Guide](USER_GUIDE.md) · [Developers](DEVELOPERS.md) · [FAQ](FAQ.md)

This roadmap tracks what is operational, in development, and planned for Nexus.

## Implemented

### Client Application

- [x] **Native macOS app:** desktop client for license activation, plugin management, version control, and background updates.
- [x] **Native Windows app:** WPF / .NET 8.0 desktop client with installer support, license activation, plugin management, update detection, rollback, and native uninstall flow.
- [x] **Silent OFX installation:** automatic plugin installation in the correct folders.
- [x] **Separate license and plugin management:** license activation, deactivation, key removal, and plugin file removal are separate actions.
- [x] **Clear license states:** messages distinguish active licenses, inactive licenses, missing plugins, suspended keys, unavailable licenses, and local license problems.
- [x] **OFX version and rollback control:** automated version checks, update notifications, previous-version installation, and rollback.
- [x] **Installation recovery flow:** retry and cancel behavior for failed installation, update, and rollback operations.

### Backend

- [x] **Dynamic multi-product engine:** stateless API for managing multiple products with zero-downtime configuration hot reloading.
- [x] **Advanced security and hardening:** secure session tokens, encrypted license payloads, progressive brute-force protection, multi-layer rate limiting, network-edge rules, and security headers.
- [x] **Secure streaming proxy:** protected binary downloads without exposing license keys.
- [x] **Aggregated device synchronization:** status synchronization and renewal of multiple licenses in one request.
- [x] **OpenKey licensing module:** distribution of open-source projects alongside commercial licensing.
- [x] **Admin Back Office:** internal portal for managing licenses, activations, releases, products, and tenants through enterprise SSO.

### Integration

- [x] **Cryptlex hardware-bound licensing:** validation tied to machine fingerprints.
- [x] **Stripe and checkout partner automation:** customer registration, user creation, and license provisioning.
- [x] **MailerLite transactional communication:** automated welcome messages and activation credentials.
- [x] **Automated CI/CD pipeline:** backend deployment and macOS DMG and Windows installer releases through GitHub Releases.
- [x] **GitHub OAuth claim links:** self-service license distribution through GitHub authentication.
- [x] **Support and operational documentation:** structured forms for application, plugin, and activation problems, plus bilingual user guides and FAQs.

### Release Infrastructure

- [x] **Platform-specific releases:** separate macOS and Windows artifacts.
- [x] **Windows installer:** `MCNexus-Setup-v{VERSION}.exe` with Start Menu shortcuts, Apps & Features registration, metadata, and uninstall support.
- [x] **Transparent Windows uninstall flow:** explains that OFX plugins may remain, allows local app and license data to be kept or removed, and closes MCNexus when necessary.

## In Development

- [ ] **Release hardening:** Windows code signing, clean-machine validation, and final release bug review.
- [ ] **macOS distribution hardening:** Apple Developer ID signing, notarization, Gatekeeper validation, and packaging improvements.
- [ ] **Product visual identity:** final application icon, installer visuals, product imagery, and brand assets.
- [ ] **License reliability:** activation reuse validation, OpenKey lifecycle improvements, and cross-platform state parity.
- [ ] **Continuous platform improvements:** application, backend, infrastructure, reliability, and release refinements.

## Planned

- [ ] **Support evolution:** diagnostic refinements, a broader solution base, and continuous improvement of forms and guides.
- [ ] **Tenant management:** soft delete with historical license and activation preservation.
- [ ] **Customer portal:** self-service management of licenses, activations, support requests, and purchase history.
- [ ] **OpenKey SDK:** native SDK for macOS, Windows, and OFX clients with activation, validation, deactivation, offline cache, and runtime checks.
- [ ] **License transfer workflow:** self-service release and reactivation when changing machines.
- [ ] **Offline grace period:** offline use window for activated licenses.
- [ ] **Signed release verification:** verification of downloaded plugin packages before installation.
- [ ] **Developer integration kit:** documentation and integration examples for plugin developers.
- [ ] **Plugin health check:** detection of missing, incompatible, or locked installations.
- [ ] **New checkout integrations:**
  - [ ] Paddle
  - [ ] FastSpring
  - [ ] Dodo Payments
  - [ ] polar.sh
  - [ ] Gumroad
- [ ] **Cross-platform expansion:**
  - [ ] Native Linux application.
- [ ] **Analytics and telemetry:** usage reports and automated crash reports for partner developers.
