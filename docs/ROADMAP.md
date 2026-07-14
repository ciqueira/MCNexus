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
- [x] **Multi-tenant Commerce:** offers, orders, payments, and commercial benefits are managed separately from technical licenses.
- [x] **Back Office commerce operations:** test and production offer creation and validation, shared payment accounts, paid-license identification, and purchase and delivery details.
- [x] **Controlled data updates:** platform changes are versioned and verified before release, with additional production safeguards.

### Integration

- [x] **Cryptlex hardware-bound licensing:** validation tied to machine fingerprints.
- [x] **Authenticated Commerce checkout:** GitHub-verified identity, duplicate-purchase prevention, protected buyer email, and safe license creation or upgrade after payment confirmation.
- [x] **Immediate completion and delivery:** purchase-source-neutral completion page with waiting and review states and protected key reveal.
- [x] **Decoupled provider foundation:** identity, payment, licensing, delivery, and email can evolve independently while preserving existing GitHub links.
- [x] **Account- and environment-scoped Stripe configuration:** one account can serve multiple offers and tenants, with secure separation between test and production.
- [x] **MailerLite operational communication:** license delivery and support confirmation prevent duplicate messages and use per-tenant operational groups; marketing remains separate and disabled without specific consent.
- [x] **Versioned legal evidence:** Commerce orders record seller and product document URLs and versions, locale, consent source and timestamp, and transaction references; legacy orders are identified when evidence is unavailable.
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
- [x] **Multiple licenses per tenant by entitlement:** allow the same tenant/product to appear more than once when the backend returns distinct plugins, keeping sync, cache, and installation separated per license.
- [ ] **Color Equalizer Commerce pilot:** complete the controlled production test matrix and review Radar, payment methods, international currency display, logs, disputes, refunds, and the fiscal/legal gate before broader promotion.
- [ ] **Commerce operations and reconciliation:** expand tracking for email, currencies, billing country, and financial history, with filters and auditable administrative actions.
- [ ] **License-attached support benefit:** turn the support months included with a purchase into an effective period with its own start, end, renewal, and communication.
- [ ] **Per-tenant legal hardening:** retain published document versions, complete the electronic cancellation workflow, and keep legal and accounting review as a launch requirement without claiming automatic compliance.
- [ ] **Legacy compatibility cleanup:** retire old integrations only after confirming that current public links remain operational.
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
- [ ] **Commerce integration expansion:** Cryptlex-backed purchases, website account or magic-link identity, and a second transactional email service.
- [ ] **Self-service tenant legal configuration:** operator, seller, and product document tree with versioned publishing, controlled inheritance, and acceptance history in the portal.
- [ ] **Advanced international commerce:** improved currency tracking, optional regional pricing, and market-specific tax support when required by the operation.
- [ ] **New checkout integrations:**
  - [ ] Paddle
  - [ ] FastSpring
  - [ ] Dodo Payments
  - [ ] polar.sh
  - [ ] Gumroad
- [ ] **Cross-platform expansion:**
  - [ ] Native Linux application.
- [ ] **Analytics and telemetry:** usage reports and automated crash reports for partner developers.
