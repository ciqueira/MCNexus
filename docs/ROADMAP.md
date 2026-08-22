# Nexus Roadmap

[English](ROADMAP.md) · [Português](../pt-BR/docs/ROADMAP.md)

[Home](../README.md) · [Discovery](DISCOVERY.md) · [User Guide](USER_GUIDE.md) · [Developers](DEVELOPERS.md) · [FAQ](FAQ.md) · [Continuity](CONTINUITY.md)

Last updated: August 22, 2026

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
- The licensing core is not specific to OFX, but OFX plugins are the only
  vertical with integrations in production. Every capability marked as
  implemented below should be read as available to OFX projects today,
  whatever the architecture permits in principle.
- Commerce capabilities and the initial Color Equalizer pilot are implemented.
  Broader promotion remains gated by expanded end-to-end operational testing
  and the applicable legal and accounting review.
- The current Commerce composition uses GitHub for identity, Stripe for
  payment, OpenKey for license fulfillment, and MailerLite for operational
  email. Cryptlex is supported for client licensing, but Commerce fulfillment
  through Cryptlex is not yet active.
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
- **Verticals — host-specific.** Packaging conventions, installation paths,
  host lifecycle, and the client experience for one kind of software. **OFX
  plugins for post-production hosts are the only vertical in production**,
  delivered through MCNexus on macOS and Windows.

- **End users** use MCNexus to activate licenses, install software, check for
  updates, install previous versions, and perform rollback.
- **Developers** use configured licensing, Commerce, release, and communication
  integrations.

OpenKey is the License Provider maintained as part of Nexus. Commerce manages
offers, orders, payments, and fulfillment. GitHub is currently used for
identity and release artifacts in the OpenKey and Commerce flows described
below.

The planned architecture allows other identity, licensing, payment, email, and
release providers. GitHub is intended to become optional. Additional verticals
are planned work and are not available today; the SDK profile that lets a
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

- [x] **OpenKey and Cryptlex support:** the Nexus-native OpenKey backend and
  Cryptlex hardware-bound commercial licensing operate through the same client
  experience.
- [x] **Multi-product and entitlement-aware licensing:** distinct products,
  editions, plugins, and multiple licenses from the same tenant remain
  separated through activation, synchronization, caching, and installation.
- [x] **Protected release delivery:** platform-specific artifacts, authenticated
  download resolution, secure streaming, version discovery, and rollback
  without exposing license keys.
- [x] **Aggregated device synchronization:** multiple licenses can be checked
  and renewed in one request while preserving their independent lifecycle.
- [x] **Public client SDK (NexKeyRuntime):** a C/C++14 SDK for update
  discovery, product notices, and offline verification of activation
  certificates, published at
  [github.com/ciqueira/NexKeyRuntime](https://github.com/ciqueira/NexKeyRuntime).
  Its public contract — the C header, JSON schemas, examples, and integration
  documentation — is Apache-2.0, and compiled static libraries for macOS
  (universal) and Windows x64 are published as releases with checksums. Two
  limits apply and are listed as separate work below: the API is still `0.x`
  and may evolve, and the license governing the compiled binaries is a draft.

### Commerce and Customer Operations

- [x] **Provider-neutral Commerce foundation:** identity, payment, licensing,
  fulfillment, delivery, and email are separated by explicit contracts instead
  of being tied to one checkout composition.
- [x] **Authenticated Stripe purchase flow:** GitHub-verified identity,
  duplicate-purchase protection, environment-scoped payment accounts,
  multi-currency Prices, idempotent fulfillment, and protected key reveal.
- [x] **Color Equalizer Commerce pilot:** one controlled production purchase
  was completed successfully, validating the configured purchase flow for that
  transaction.
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
- [x] **Release compatibility validation:** the existing public claim,
  purchase, activation, and download links were verified after the provider
  and legacy-path changes and are operational.
- [x] **Operational documentation:** bilingual user, developer, legal, support,
  and troubleshooting documentation accompanies the platform.

## Current Work

Current work covers code signing, package verification, license behavior, and
expanded Commerce validation and operations.

- [ ] **Code signing and release validation:** sign the direct Windows
  installer, sign and notarize the macOS application, validate Gatekeeper and
  SmartScreen behavior, and test releases on clean machines. The Microsoft
  Store remains the official Windows channel during this work.
- [ ] **Package integrity:** publish authoritative release metadata and verify
  downloaded plugin packages before installation.
- [ ] **License lifecycle consistency:** complete activation-reuse validation,
  OpenKey lifecycle refinements, and behavioral parity between macOS and
  Windows.
- [ ] **Commerce production coverage and legal operations:** expand controlled
  validation across payment methods, currencies, Radar review, delivery,
  support benefits, logs, and recovery scenarios; add refund and dispute
  workflows, billing-country visibility, financial exports, electronic
  cancellation, and the required legal and accounting launch reviews.

## Planned — Self-Service

- [ ] **Customer portal:** allow customers to view purchases and licenses,
  manage activations, transfer a license to a replacement machine, recover
  access, and contact the correct support channel.
- [ ] **Offline operation and plugin checks:** introduce a controlled offline
  grace period and plugin health checks for missing, incompatible, incomplete,
  or locked installations.
- [ ] **Developer integration kit:** the client SDK is published and
  documented (see NexKeyRuntime above). What remains is the release-manifest
  specification, the package-integrity workflow, and integration tests for
  macOS, Windows, and OFX projects.
- [ ] **Binary license for third parties:** the license governing compiled
  NexKeyRuntime releases is a draft pending review, so the published binaries
  are not yet cleared for use by developers outside Nexus. The repository's own
  contents remain Apache-2.0 and usable today. This, rather than the SDK's
  availability, is what currently gates third-party adoption.
- [ ] **API stability commitment:** while the SDK is `0.x`, its public API may
  still evolve. Result codes are append-only by policy and are never reused or
  renumbered, but no 1.0 compatibility commitment has been made.
- [ ] **OpenKey and Commerce integration:** support free or paid entitlements
  through the same flow, with GitHub available as an identity and release
  adapter instead of a mandatory dependency.
- [ ] **Commerce-connected License Providers:** complete idempotent and
  reconcilable Cryptlex fulfillment, then validate Keygen or another licensing
  backend through the same Commerce contracts.
- [ ] **Direct provider integration framework:** normalize provider accounts,
  product and price mappings, signed events, idempotency, reconciliation, and
  account ownership before connecting another commercial provider.
- [ ] **Email provider separation:** keep operational messages and consented
  marketing audiences under separate contracts, then validate one additional
  transactional-email provider.
- [ ] **Channel-independent distribution:** accept normalized purchase, grant,
  and entitlement events from Nexus Commerce or authorized external sales
  channels and route them through the same distribution lifecycle.
- [ ] **Release-source flexibility:** extend the current GitHub Releases and
  Cryptlex release sources with S3-compatible controlled storage without
  changing the client installation, update, and rollback experience.
- [ ] **Developer-assisted publishing:** standardize product onboarding,
  credentials, release validation, and publication before opening them as
  fully self-service operations.
- [ ] **Tenant lifecycle:** replace destructive deletion with controlled
  deactivation, retention, export, restore, and final deletion policies that
  preserve required license, activation, purchase, and audit history.
- [ ] **Asynchronous delivery:** add queues, automatic retries,
  suppression and bounce reconciliation, and provider-neutral delivery
  monitoring.

## Planned — Continuity and Tenant Portability

This is planned work, not a current capability or guarantee. The technical
design may evolve as the licensing model, operational requirements, and
developer feedback mature. A documented and tested mechanism is required
before MCNexus is presented as continuity-safe infrastructure for external
commercial developers.

[Continuity and Recovery](CONTINUITY.md) documents the scenarios this covers,
what already holds today, and what is still intent rather than capability.

- [ ] **Continuity policy:** define temporary outage, planned wind-down, and
  operator-unavailability scenarios, including notice where possible,
  responsibilities, release conditions, and the treatment of perpetual and
  subscription licenses.
- [ ] **Tenant data and artifact portability:** provide documented, versioned
  exports of products, releases, licenses, entitlements, and activation
  records, while allowing developers to retain and redistribute their own
  verified release artifacts.
- [ ] **Independent recovery path:** design a narrowly scoped, cryptographically
  verifiable mechanism through which a developer can install and activate
  legitimate customers for its own products without the hosted Nexus service.
  Evaluate portable license certificates, developer-controlled recovery
  authority, signed local packages, and a standalone recovery tool without
  committing the platform to a specific design prematurely.
- [ ] **Recovery verification:** document and test the selected flow on clean
  macOS and Windows environments with the hosted services unavailable,
  including rejection of modified, unsigned, expired, or out-of-scope
  licenses and packages.

## Planned — Verticals Beyond OFX

The licensing core is host-independent, but a vertical is more than licensing:
it needs packaging conventions, installation paths, host lifecycle handling,
and a client experience. None of the items below is available today, and no
order or date between them is committed.

- [ ] **Host-independent activation (SDK Profile B) for third parties:** the
  SDK implements activation, synchronization, and deactivation without MCNexus
  in the loop, and the gateway routes it calls are deployed. The capability is
  not the gap. What is missing is everything around it for a developer outside
  Nexus: an approved binary license, and a way to obtain a tenant and a
  ProductData blob without a per-project setup conversation.
- [ ] **Runtimes beyond C and C++:** evaluate which language bindings are
  actually required by the runtimes independent developers ship, before
  committing to any of them.
- [ ] **Additional plugin hosts:** evaluate audio plugin formats and further
  video, 3D, and CAD hosts. Each host needs its own packaging and installation
  adapter, and each is a separate decision.
- [ ] **Standalone desktop applications:** support developers who ship their own
  installer and need licensing, updates, and rollback without adopting MCNexus
  as the delivery client.
- [ ] **Linux support:** currently limited by machine identification and by the
  absence of a platform lifecycle, not by the licensing model.

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

- [ ] **Checkout integrations:** evaluate new order sources beyond the current
  Stripe composition, normalizing their events into Nexus Commerce and
  fulfilling licenses through the configured License Provider.
  - **Commercial checkouts:** evaluate Lemon Squeezy first; compare Polar,
    Dodo Payments, and FastSpring after the provider-neutral foundation and
    current Commerce gates are complete.
  - **Additional direct checkouts:** evaluate PayPal/Braintree as a global
    alternative for direct payments, recurring billing, and additional payment
    methods.
  - **Existing checkouts and storefronts:** evaluate Gumroad, ThriveCart,
    Sellfy, Shopify, and WooCommerce only when an integrated developer has a
    concrete operational requirement.
  - **Regional checkouts:** evaluate Mercado Pago and PagBank when local
    payment methods in Brazil or Latin America become a validated requirement.
- [ ] **Licensing integrations:** evaluate Keygen after Commerce fulfillment
  through Cryptlex is complete and compare LicenseSpring as another licensing
  and product-versioning candidate.
- [ ] **Release and artifact distribution:** validate S3-compatible storage
  using Cloudflare R2 as the first implementation target, and evaluate Keygen
  Software Distribution, Cloudsmith, and GitLab Releases as managed solutions.
  Storage, version catalogs, and download authorization must remain independent
  Nexus capabilities.
- [ ] **Transactional email:** compare Postmark and Resend for operational
  communication and evaluate Cloudflare Email Service after it stabilizes.
  Mailchimp remains a separate candidate for consented marketing.
- [ ] **Identity:** evaluate WorkOS AuthKit, Clerk, and ZITADEL for identity,
  organizations, and access in the future SaaS model while retaining GitHub as
  an adapter for the current flows during the transition.
- [ ] International Commerce capabilities such as regional pricing, expanded
  currency reporting, and market-specific tax support where operationally
  required.
- [ ] Team licensing, seats, bundles, and richer product-entitlement models.
- [ ] A native Linux client when supported plugins and user demand justify the
  additional platform lifecycle.
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
