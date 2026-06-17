# Nexus
## Distribution and Licensing Infrastructure

Nexus is a unified system to automate the distribution, licensing, and installation of OFX plugins. The platform connects the registration, sales, or distribution workflow directly to the end-user's machine — supporting both commercial products with key-protected activation and open-source projects without third-party licensing dependencies.

### Key Features & Highlights

* **Commercial or Open Distribution**: Full support for both activation-key-protected tools and free (Open Source) distribution.
* **Dedicated Validation Channels**: Native pipelines to organize plugins into Beta (closed testing), Demo (limited demonstrations), and Full (complete commercial version) editions.
* **Automated Installation (Frictionless)**: The application installs the plugin silently into the correct destination folder, eliminating the need for manual procedures or configurations by the user.
* **Version Management and Rollback**: Complete control over new releases with direct notifications. The system allows reverting to previous editions with a single click if compatibility with older projects is needed.
* **License Autonomy (Node-Locked)**: Activation is tied to the computer's hardware. It allows the user to transfer the license between computers directly through the application, reducing support demand.

### Two Distribution Models

**Commercial**
For paid plugins. The customer purchases through Stripe or integrated checkout partners and automatically receives a license key. Activation is hardware-bound to the user's machine, with support for Demo and Full editions.

**Open (OpenKey)**
For open-source projects that want to distribute plugins without depending on external licensing services. Also supports hybrid models: free distribution for everyone alongside a paid tier integrated with Stripe for advanced features. Releases are delivered directly from GitHub.

In both models, the end-user experience is the same: one key (or direct access link), and the app installs the plugin automatically.

---

### Application Compatibility

* **macOS**: Native support implemented for macOS 15 or higher, including Apple Silicon and supported Intel Macs.
* **Windows**: Native support available in active testing for Windows 10/11 x64 systems, with Windows 11 ARM support through x64 emulation.
* **Linux**: Support planned soon.

### The 3-Step Process

1. **Input**: Purchase via Stripe (commercial) — or direct access link (open distribution).
2. **Processing**: Automatic transaction validation, license generation, and access instruction delivery.
3. **Consumption**: Key input in the client application, with automatic plugin installation on the system.

### Native Integrations

Direct connectivity with standard industry infrastructure:

* **Gateways**: Stripe and checkout partners.
* **Licensing**: Cryptlex (commercial) · OpenKey (open distribution).
* **Transactional Email**: Mailerlite and Mailchimp.

### Feature Roadmap

Track the development status of Nexus, including what is operational, in progress, and planned for the future:

#### Implemented

* **Client Application**
  - [x] **Native macOS App**: Desktop client designed for license activation, plugin management, version control, and background updates.
  - [x] **Native Windows App**: WPF / .NET 8.0 desktop client with installer support, license activation, plugin management, update detection, rollback, and native uninstall flow.
  - [x] **Silent OFX Installation**: Automatic installation of plugins directly into correct folders without manual user intervention.
  - [x] **Separated License and Plugin Management**: License activation, deactivation, key removal, and plugin file removal are handled as separate user actions for clearer control.
  - [x] **Clear License States**: User-facing status messages distinguish active licenses, inactive licenses, missing plugins, suspended keys, unavailable licenses, and local license issues.
  - [x] **OFX Version & Rollback Control**: Automated version checking, update notifications, previous-version installation, and rollback support within the application.
  - [x] **Installation Recovery Flow**: Clear retry and cancel behavior when installation, update, or rollback steps fail.

* **Backend**
  - [x] **Dynamic Multi-Product Engine**: High-performance, stateless API managing multiple products dynamically with zero-downtime hot-reloading configurations.
  - [x] **Advanced Security & Hardening**: Secure session tokens with encrypted license payloads, progressive brute-force protection, granular multi-layer rate limiting backed by globally distributed counters (not per-instance memory), network-edge rate limiting rules on sensitive endpoints, and security headers on all responses.
  - [x] **Secure Streaming Proxy**: Safe downloads of binary releases via a secure backend proxy, protecting upstream storage and preventing license key exposure.
  - [x] **Aggregated Device Synchronization**: High-performance heartbeat mechanism to sync status and renew multiple license keys in a single request, optimizing network overhead on user devices.
  - [x] **OpenKey Licensing Module**: Support for open-source and free distribution alongside commercial licensing, enabling flexible deployment models without third-party licensing dependencies.
  - [x] **Admin Back Office**: Internal administration portal for managing licenses, activations, and releases across all products and tenants, protected by enterprise SSO authentication.

* **Integration**
  - [x] **Cryptlex Hardware-Bound Licensing**: License validation tied securely to unique machine fingerprints using Cryptlex, preventing unauthorized key sharing.
  - [x] **Stripe & Checkout Partners Automation**: Automatic customer registration, user creation, and instant license provisioning triggered by Stripe and integrated checkout partner events.
  - [x] **Mailerlite Transactional Communications**: Automated welcome messages and immediate activation credentials delivery via Mailerlite transactional email services.
  - [x] **Automated CI/CD Pipeline**: Fully automated deployment of backend infrastructure and app releases, including macOS DMG builds and Windows installer builds published through GitHub Releases.
  - [x] **GitHub OAuth Claim Links**: Self-service license distribution via GitHub authentication — users click a signed link, authorize with their GitHub account, and receive their license key instantly, with no manual intervention required.

* **Release Infrastructure**
  - [x] **Platform-Specific Releases**: GitHub releases support separate macOS and Windows artifacts.
  - [x] **Windows Installer**: Dedicated installer generated as `MCNexus-Setup-v{VERSION}.exe`, with Start Menu shortcuts, Add/Remove Programs registration, app metadata, and native uninstall support.
  - [x] **Transparent Windows Uninstall Flow**: The Windows uninstaller explains that installed OFX plugins may remain on disk, allows users to keep or remove local app/license data, and closes MCNexus automatically if it is running.

#### In Development

- [ ] **Release Hardening**: Windows code signing, clean-machine validation, and final release-level bug review.
- [ ] **macOS Distribution Hardening**: Apple Developer ID signing, notarization, Gatekeeper validation, and release packaging improvements.
- [ ] **Product Visual Identity**: Final app icon, installer visuals, product imagery, and brand assets.
- [ ] **License Reliability**: Activation reuse validation, OpenKey lifecycle improvements, and cross-platform state parity.
- [ ] **Continuous Platform Improvements**: Ongoing app, backend, and infrastructure improvements, including bug fixes, reliability work, and release refinements.

#### Planned

- [ ] **User Support & Trust**: Support path, diagnostics improvements, and practical user documentation.
- [ ] **Tenant Management**: Soft Delete — safe tenant removal with full historical data preservation; licenses and activations are retained in the database rather than permanently deleted.
- [ ] **Customer Portal**: Self-service web portal for end-customers to manage licenses, activations, support requests, and purchase history.
- [ ] **OpenKey SDK**: Native SDK for macOS, Windows, and OFX clients, providing activation, validation, deactivation, offline cache, and runtime license checks.
- [ ] **License Transfer Workflow**: Self-service release and reactivation flow for users changing machines.
- [ ] **Offline Grace Period**: Safe offline usage window for already activated licenses.
- [ ] **Signed Release Verification**: Verify downloaded plugin packages before installation.
- [ ] **Developer Integration Kit**: Documentation and sample integrations for plugin developers.
- [ ] **Plugin Health Check**: Detect missing, incompatible, or locked plugin installations.
- [ ] **New Checkout Integrations**:
  - [ ] Paddle
  - [ ] FastSpring
  - [ ] Dodo Payments
  - [ ] polar.sh
  - [ ] Gumroad
- [ ] **Cross-Platform Expansion**:
  - [ ] Native client app for Linux.
- [ ] **Analytics and Telemetry**: Usage reports and automated crash reports for partner developers.

---

### Contact & Support

For questions, support, or additional information:

* **Email**: nexus@magnociqueira.com.br
* **Privacy Policy**: [Português / English](PRIVACY.md)
* **LinkedIn**: [ciqueira](https://www.linkedin.com/in/ciqueira/)
* **Instagram**: [@magnociqueira](https://www.instagram.com/magnociqueira/)
* **Issues and Feedback**: To report bugs or suggest improvements, please open an issue in this repository.

![Nexus Screen](screen_app.png)
