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

* **macOS**: Native support implemented (for macOS 15 or higher).
* **Windows**: Support planned soon.
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
  - [x] **Native macOS App**: Desktop client designed for license activation, plugin management, and background updates.
  - [x] **Silent OFX Installation**: Automatic installation of plugins directly into correct folders without manual user intervention.
  - [x] **OFX Version & Rollback Control**: Automated version checking, update notifications, and one-click rollback within the application.

* **Backend**
  - [x] **Dynamic Multi-Product Engine**: High-performance, stateless API managing multiple products dynamically with zero-downtime hot-reloading configurations.
  - [x] **Advanced Security & Hardening**: Secure session tokens with encrypted license payloads, progressive brute-force protection to slow down unauthorized validation attempts, and granular multi-layer rate limiting.
  - [x] **Secure Streaming Proxy**: Safe downloads of binary releases via a secure backend proxy, protecting upstream storage and preventing license key exposure.
  - [x] **Aggregated Device Synchronization**: High-performance heartbeat mechanism to sync status and renew multiple license keys in a single request, optimizing network overhead on user devices.
  - [x] **OpenKey Licensing Module**: Support for open-source and free distribution alongside commercial licensing, enabling flexible deployment models without third-party licensing dependencies.
  - [x] **Admin Back Office**: Internal administration portal for managing licenses, activations, and releases across all products and tenants.

* **Integration**
  - [x] **Cryptlex Hardware-Bound Licensing**: License validation tied securely to unique machine fingerprints using Cryptlex, preventing unauthorized key sharing.
  - [x] **Stripe & Checkout Partners Automation**: Automatic customer registration, user creation, and instant license provisioning triggered by Stripe and integrated checkout partner events.
  - [x] **Mailerlite Transactional Communications**: Automated welcome messages and immediate activation credentials delivery via Mailerlite transactional email services.

#### In Development
- [ ] **Checkout Integration**:
  - [ ] Paddle
  - [ ] FastSpring
- [ ] **OpenKey Distribution (Client)**:
  - [ ] GitHub Releases CI/CD — automated release publishing on tag push
  - [ ] Claim Links System — self-service license distribution via GitHub OAuth
  - [ ] Native macOS SDK integration (OpenKey provider for MCAppsTools)

#### Planned
- [ ] **Cross-Platform Compatibility**:
  - [ ] Native client app for Windows.
  - [ ] Native client app for Linux.
- [ ] **New Integrations**:
  - [ ] keygen.sh
  - [ ] Dodo Payments
  - [ ] polar.sh
  - [ ] Gumroad
- [ ] **User Control Panel**: Self-service web portal for end-customers to manage their own activations, transfer licenses between machines, and view purchase history — distinct from the internal admin back office.
- [ ] **Analytics and Telemetry**: Usage reports and automated crash reports for partner developers.

---

### Contact & Support

For questions, support, or additional information:

* **Email**: contato@magnociqueira.com.br
* **LinkedIn**: [ciqueira](https://www.linkedin.com/in/ciqueira/)
* **Instagram**: [@magnociqueira](https://www.instagram.com/magnociqueira/)
* **Issues and Feedback**: To report bugs or suggest improvements, please open an issue in this repository.

![Nexus Screen](screen_app.png)
