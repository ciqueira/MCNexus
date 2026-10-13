# Nexus Roadmap

[English](ROADMAP.md) · [Português](../pt-BR/docs/ROADMAP.md)

[Home](../README.md) · [Discovery](DISCOVERY.md) · [User Guide](USER_GUIDE.md) · [Developers](DEVELOPERS.md) · [FAQ](FAQ.md) · [Continuity](CONTINUITY.md)

Last updated: October 12, 2026

This roadmap separates implemented capabilities, current work, planned work,
and items under consideration. Known limitations and remaining validation
requirements are included with the related work. The roadmap does not assign
speculative delivery dates.

## How to Read This Roadmap

- A checked item means the capability is implemented in the current code and
  operating model. It does not by itself claim an SLA, independent security
  certification, universal host compatibility, or automatic legal compliance.
- An unchecked item is not yet available as a complete capability. Its scope
  may change as testing, production evidence, and developer feedback are
  collected.
- The Microsoft Store is the official and recommended Windows channel. The
  direct Windows installer is not currently code-signed, and the macOS build is
  not yet signed with Apple Developer ID or notarized.
- Developer integrations are currently reviewed and configured per project.
  There is no public onboarding API or fully self-service developer portal.
- The licensing core is not specific to OFX. OFX plugins for post-production
  hosts are the kind of software served today; other kinds are planned work,
  listed below.
- Commerce capabilities are implemented.
  Broader promotion remains gated by expanded end-to-end operational testing
  and the applicable legal and accounting review.
- Each provider layer — identity, payment, licensing, fulfillment, email, and
  release source — is separated by an explicit contract. What is connected
  today, and what is on the roadmap for each layer, is listed in
  [Developers](DEVELOPERS.md) §8.
- Internal multi-tenancy is not presented as a public SaaS offering. External
  organizations, membership and RBAC, public onboarding, tenant-scoped service
  billing, and contractual SaaS operations remain future work.

## Product Scope

Nexus manages licensing, release delivery, installation, updates, and rollback
for native software that has to keep working without a network connection. It
receives a license, purchase, or authorized grant, resolves the applicable
entitlement and release, and makes the artifact available to the client.

The platform is organized in two layers, and they advance independently.

- **Licensing core — host-independent.** Activation certificates signed per
  tenant, machine binding, entitlements, seat control, an offline validity
  window, synchronization policy, and an audit trail. An activation certificate
  is scoped to a tenant and a machine; it does not carry a product, an
  artifact, or a plugin format.
- **Delivery layer — host-specific.** Packaging conventions, installation
  paths, host lifecycle, and the client experience for one kind of software.
  **OFX plugins for post-production hosts are the kind served
  today**, delivered through MCNexus on macOS and Windows.

- **End users** use MCNexus to activate licenses, install software, check for
  updates, install previous versions, and perform rollback.
- **Developers** use configured licensing, Commerce, release, and communication
  integrations.

OpenKey is the License Provider maintained as part of Nexus. Commerce manages
offers, orders, payments, and fulfillment. GitHub is currently used for
identity and release artifacts in the OpenKey and Commerce flows described
below.

The planned architecture allows other identity, licensing, payment, email, and
release providers. GitHub is intended to become optional. Additional kinds of
software are planned work and are not available today; the SDK profile that lets a
product activate a license without MCNexus in the loop is implemented, but
opening it to developers outside Nexus depends on the binary license and
onboarding work listed below. The planned SaaS work adds external
organizations, access control, onboarding, service billing, and tenant
isolation.

## Implemented Capabilities

### Desktop Experience and Distribution

- [x] **Official Windows distribution:** MCNexus is available from the
  [Microsoft Store](https://apps.microsoft.com/detail/9n1qqt1xc825), the
  official and recommended Windows channel, with Store-managed distribution
  and automatic background updates. A direct installer remains available as
  an alternative, with the signing limitation described above.
- [x] **Native macOS and Windows applications:** platform-specific clients for
  license activation, plugin management, update detection, installation of
  previous versions, and rollback.
- [x] **OFX installation and removal:** automatic installation in native system
  locations, explicit separation between license and plugin actions,
  installation recovery, and transparent uninstall behavior.
- [x] **Clear operational states:** users can distinguish active and inactive
  licenses, unavailable products, missing plugins, local problems, updates,
  and rollback options.

### Licensing and Release Platform

- [x] **OpenKey and Cryptlex support:** the Nexus-native OpenKey backend
  issues the license for a free product and for a paid one, through the same
  client experience as the alternative Cryptlex backend. Both do
  hardware-bound, node-locked activation.
- [x] **Multi-product and entitlement-aware licensing:** distinct products,
  editions, plugins, and multiple licenses from the same tenant remain
  separated through activation, synchronization, caching, and installation.
- [x] **Protected release delivery:** platform-specific artifacts, authenticated
  download resolution, secure streaming, version discovery, and rollback
  without exposing license keys.
- [x] **Package integrity:** downloaded plugin packages are verified before
  installation. Each release carries a manifest declaring its assets and their
  client requirements, and downloads are refused when a client does not meet
  them; beyond that, every asset is published with a SHA256 digest that the
  application checks against the downloaded file before installing. A package
  whose digest does not match is refused and discarded, never installed.
- [x] **Aggregated device synchronization:** multiple licenses can be checked
  and renewed in one request while preserving their independent lifecycle.
- [x] **Offline validity window:** an activation certificate carries two
  independent deadlines — when renewal starts being attempted, and the hard
  limit the SDK itself enforces. The default window is 30 days, configurable
  per license up to 365, and the issuer guarantees it always covers at least
  two whole renewal attempts, so a single failed sync can never be what denies
  a license. End-to-end validation on real installations is tracked separately
  under Continuity below.
- [x] **Offline activation for machines with no network:** a machine can export
  an activation request, receive a certificate issued elsewhere, and install it
  without ever reaching the network; the same path releases the seat again with
  a deactivation proof. Certificates are verified against the product's keyring
  on import and on every load afterwards, so this route weakens nothing. Used
  for air-gapped installations, and the same mechanism the recovery path in
  Continuity relies on.
- [x] **Public client SDK (NexKeyRuntime):** a C/C++14 SDK for update
  discovery, product notices, and offline verification of activation
  certificates, published at
  [github.com/ciqueira/NexKeyRuntime](https://github.com/ciqueira/NexKeyRuntime).
  Its public contract — the C header, JSON schemas, examples, and integration
  documentation — is Apache-2.0, and compiled static libraries for macOS
  (universal) and Windows x64 are published as releases with checksums. The
  public API is stable as of `1.0`, under the compatibility policy published in
  the repository.
- [x] **Binary license for third parties:** the license governing compiled
  NexKeyRuntime releases (`BINARY_LICENSE.md`) is finalized, clearing the
  published binaries for use by developers outside Nexus. Linking the binary
  into your own product is free under any Nexus plan, including the free
  Comunidade plan; a commercial plan is only required if the product you ship
  charges its own end users. The repository's own contents remain Apache-2.0
  and usable today.

### Commerce and Customer Operations

- [x] **Provider-neutral Commerce foundation:** identity, payment, licensing,
  fulfillment, delivery, and email are separated by explicit contracts instead
  of being tied to one checkout composition.
- [x] **Authenticated Stripe purchase flow:** GitHub-verified identity,
  duplicate-purchase protection, environment-scoped payment accounts,
  multi-currency Prices, idempotent fulfillment, and protected key reveal.
- [x] **Operational purchase records:** offers, orders, payments, support
  benefits, fulfillment, and email delivery are managed separately from the
  technical license and are visible in the Back Office.
- [x] **Auditable customer communication and legal evidence:** operational
  messages avoid duplicate delivery, support controlled resend, and preserve
  the document versions, locale, consent, and transaction references attached
  to each Commerce order.

### Platform Operations and Security

- [x] **Internal multi-tenant Back Office:** products, tenants, releases,
  licenses, activations, payment accounts, Commerce Offers, and operational
  history are managed through protected administrative access.
- [x] **Security controls:** encrypted tenant configuration, secure session
  tokens, protected license payloads, rate limiting, network-edge controls,
  security headers, and structured audit records.
- [x] **Controlled delivery pipeline:** backend changes and database migrations
  follow versioned verification, staging, and promotion gates. macOS and
  Windows packages are produced as platform-specific artifacts through
  versioned release workflows.
- [x] **Operational documentation:** bilingual user, developer, legal, support,
  and troubleshooting documentation accompanies the platform.

## Current Work

Current work covers code signing, license behavior, and expanded Commerce
validation and operations.

- [ ] **Code signing and release validation:** sign the direct Windows
  installer, sign and notarize the macOS application, validate Gatekeeper and
  SmartScreen behavior, and test releases on clean machines. The Microsoft
  Store remains the official Windows channel during this work.
- [ ] **License lifecycle consistency:** complete activation-reuse validation,
  OpenKey lifecycle refinements, and behavioral parity between macOS and
  Windows.
- [ ] **Commerce production coverage and legal operations:** expand controlled
  validation across payment methods, currencies, Radar review, delivery,
  support benefits, logs, and recovery scenarios; add refund and dispute
  workflows, billing-country visibility, financial exports, electronic
  cancellation, and the required legal and accounting launch reviews.

## Planned — Software Protection and Intellectual Property

This work advances beyond transport security into runtime IP protection,
raising the engineering and mathematical cost of unauthorized binary tampering
without impacting host stability or real-time processing budgets.

- [ ] **Asset & Shader Vault (in-memory GPU asset protection):** encrypted
  packaging (AES-256) for compiled GPU shaders (Metal, HLSL, CUDA), neural
  network inference models, and convolution tables. Shaders and kernels are
  decrypted Just-in-Time directly into graphics or process memory bound to an
  active certificate, without ever writing raw unencrypted assets to the host
  disk.
- [ ] **Crypto-bound execution:** cryptographic derivation of essential
  pipeline constants, color transformation matrices, and DSP filter
  coefficients directly from verified Ed25519 certificates and hardware machine
  fingerprints. Replaces easily patched boolean checks with functional
  dependencies, ensuring the processing algorithm only computes legitimate
  output when mathematically verified.
- [ ] **Hardware enclave binding:** bind client node-locks to dedicated
  hardware security silicon (Apple Secure Enclave on macOS and TPM 2.0 on
  Windows), elevating protection against machine fingerprint cloning and
  virtualized spoofing.
- [ ] **Runtime anti-tampering and binary integrity:** active protection of
  plugin binaries against automated reverse engineering, incorporating
  control-flow flattening, compile-time string and symbol eradication, and
  continuous in-memory code section integrity validation to neutralize binary
  patches.

## Planned — Desktop Experience and Studio Workflows

- [ ] **Batch management (Update All and Install All):** centralized background
  queue in MCNexus to download and verify multiple licensed plugins in parallel,
  with sequential and host-safe installation when host applications are closed.
- [ ] **Studio profile and version locking:** project-level and suite-level
  version pinning, enabling multi-seat post-production studios to freeze
  plugin versions across an entire facility during long-form projects and avoid
  accidental updates during active deliveries.
- [ ] **Elastic licensing and render passes (Guest Pass & Overdraft):**
  safeguards to prevent missed delivery deadlines and accidental watermarks
  during production render spikes. Enables issuing temporary cryptographic
  guest passes for dedicated render nodes or freelance assistants (including
  headless-only background rendering without a graphical interface), alongside
  pre-approved emergency license burst capacity (overdraft) reconciled post-hoc
  via cryptographic local receipts.

## Planned — Self-Service

- [ ] **Customer portal:** allow customers to view purchases and licenses,
  manage activations, recover access, and contact the correct support channel.
  Moving a license between machines already works without support when the
  previous machine is reachable — online or air-gapped. What this item adds is
  the case where that machine is lost, reformatted, or dead, which today goes
  through the activation-problem form.
- [ ] **Plugin health checks:** detect and report missing, incompatible,
  incomplete, or locked installations, as well as host version and architecture
  mismatches.
- [ ] **Developer integration kit:** release manifest specifications, asset
  requirements, package-integrity workflow, and automated integration tests for
  macOS, Windows, and native host projects.
- [ ] **Decoupled provider integrations:** support email and magic-link
  authentication alongside GitHub, normalized direct payment provider
  connections, and independent transactional email routing.
- [ ] **Flexible release storage:** extend release artifact delivery with
  S3-compatible and Cloudflare R2 storage without altering client verification
  or rollback.
- [ ] **Developer publishing and tenant lifecycle:** standardize onboarding
  workflows, publication checklists, and controlled tenant lifecycle
  (deactivation, retention, and data exports).

## Planned — Continuity and Tenant Portability

This is planned work, not a current capability or guarantee. The technical
design may evolve as the licensing model, operational requirements, and
developer feedback mature. A documented and tested mechanism is required
before MCNexus is presented as continuity-safe infrastructure for external
commercial developers.

[Continuity and Recovery](CONTINUITY.md) documents the scenarios this covers,
what already holds today, and what is still intent rather than capability.

- [ ] **Recovery verification:** test and validate the existing cryptographic
  recovery key mechanism on clean macOS and Windows environments with hosted
  services unavailable, verifying offline issuance and strict rejection of
  tampered or out-of-scope licenses.
- [ ] **Tenant data and artifact portability:** provide documented, versioned
  exports of products, releases, licenses, entitlements, and activation
  records, while allowing developers to retain and redistribute their own
  verified release artifacts.

## Planned — Beyond OFX

The licensing core is host-independent, but serving a new kind of software is
more than licensing: it needs packaging conventions, installation paths, host
lifecycle handling, and a client experience. None of the items below is available today, and no
order or date between them is committed.

- [ ] **Professional audio plugin formats:** packaging and native installation
  adapters for audio DSP plugins (VST3, Audio Units, AAX), providing audio
  developers a modern, dongle-free alternative to legacy copy protection.
- [ ] **Language bindings for the C SDK:** first-party bindings for .NET,
  Python, Rust, and Swift built over the stable C API of NexKeyRuntime, enabling
  studio pipeline tools, scripts, and standalone applications to use Nexus
  licensing.
- [ ] **Host-independent activation (SDK Profile B) for third parties:** self-service
  onboarding and ProductData provisioning for developers shipping their own
  custom installers without MCNexus as the delivery client.
- [ ] **Linux support:** workstation and render node execution, currently
  limited by machine identification and platform lifecycle rather than the
  licensing core.

## Planned — SaaS Preparation

This work is required before an external developer organization can configure
and operate products through the service.

- [ ] **Organizations, membership, and RBAC:** introduce an
  Organization/Seller boundary with owners, members, roles, and least-privilege
  access to products and operations.
- [ ] **Developer portal and onboarding:** provide guided organization,
  seller, product, provider-account, legal-profile, and release setup with
  validation before production activation.
- [ ] **Tenant ownership and isolation:** bind products, credentials, payment
  and email accounts, legal evidence, and audit history to an organization;
  add authorization, key rotation, and cross-tenant isolation tests.
- [ ] **Self-service legal configuration:** support versioned seller and
  product documents, controlled inheritance, publication history, consent
  evidence, and environment-specific launch gates.
- [ ] **Nexus service billing:** define plans, quotas, usage measurement, trial
  and subscription lifecycle, and billing for the Nexus service independently
  from Commerce transactions made by each plugin seller.
- [ ] **SaaS legal and operational package:** establish the service agreement,
  DPA, subprocessor list, acceptable-use policy, support policy, SLA/SLOs,
  incident response, data export, and termination process.
- [ ] **Service resilience:** provide per-organization auditability,
  observability, backup and restore verification, capacity controls, and
  documented recovery objectives.

## Under Consideration

These directions are evaluated after the preceding milestones and do not
represent commitments to a particular provider or date.

- [ ] Local network floating seats (LAN Floating Pool) for dynamic license
  sharing across render farms and editing suites without continuous internet
  access.
- [ ] International Commerce capabilities such as regional pricing, expanded
  currency reporting, and market-specific tax support where operationally
  required.
- [ ] Privacy-conscious, opt-in crash reporting and product insights for
  participating developers.
The candidates above assume provider accounts connected directly by Nexus for
its own service or by each plugin seller for their products. A Nexus-operated
marketplace, aggregated Merchant of Record account, and shared seller-funds
model are outside the current scope.

## Development Principles

- Validate a complete operational flow before expanding it to more products or
  providers.
- Preserve provider-neutral domain boundaries and avoid making customer rights
  depend on a third-party provider's internal state.
- Keep distribution independent of a single sales channel, licensing backend,
  payment provider, email provider, or release host.
- Maintain backward compatibility for public links, licenses, releases, and
  audit history through explicit migrations.
- Treat tenant isolation, security, privacy, and recoverability as product
  requirements rather than later infrastructure work.
- Promote work by milestone evidence and launch gates; priorities may change
  as production findings and developer feedback are validated.
