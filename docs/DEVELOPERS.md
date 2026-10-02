# Developer Documentation

[English](DEVELOPERS.md) · [Português](../pt-BR/docs/DEVELOPERS.md)

[Home](../README.md) · [Discovery](DISCOVERY.md) · [User Guide](USER_GUIDE.md) · [FAQ](FAQ.md) · [Roadmap](ROADMAP.md) · [Continuity](CONTINUITY.md)

Nexus provides infrastructure for licensing, distributing, and updating
software. This page is the common intake and handoff guide for developers: it
collects the information needed to assess a project, configure its tenant, and
return the project-specific values needed to integrate NexKeyRuntime.

Use the same intake for plugins, desktop applications, and other products.
The OFX integration is the only host integration currently running in
production. Other hosts and product types can be proposed, but require a
technical review before support or a delivery date can be confirmed; see the
[Roadmap](ROADMAP.md).

> **Current process:** integrations are reviewed and configured manually, per
> project. There is no public onboarding API or self-service tenant creation.
> The checklist below is an intake, not a promise that every requested host,
> provider, or workflow is already supported.

## 1. Project intake

Send the information below through a private channel or by email to [hello@mcnexus.app](mailto:hello@mcnexus.app). Mark items that
do not apply as `N/A`; payment, legal, and release details are only needed when
the corresponding service is part of the requested integration.

### Copyable project form

```text
Developer / organization:
Technical contact and email:
Product name and short description:
Product website (if available):

Product type: plugin / desktop app / other
Host application(s) and versions:
Target operating systems and architectures:
Implementation language and build system:
Current product version and planned test date:

Nexus services requested: licensing / release updates / notices / downloads / commerce
License integration: Profile A (MCNexus activates) / Profile B (product activates) / undecided / N/A
Licensing provider: OpenKey / Cryptlex / other / undecided
Product model: free / paid / both
Editions, activation limits, and what each edition includes:
Entitlements or product variants, and what each one unlocks:

Release provider:
Repository or release URL (if applicable):
Repository visibility: public / private / N/A
First release or test artifact URL:
Release formats and filenames:
Release channels: stable / beta / other

Existing license/customer flow (if any):
Required offline or air-gapped workflow:
Anything else needed for the first integration:
```

Do not include passwords, license keys, access tokens, signing keys, or other
secrets in this form. If a private GitHub repository is used, repository
access is arranged separately with a fine-grained token limited to that one
repository and `Contents: Read-only`, shared through an approved secure
channel. Public repositories do not require a release token.

The developer remains responsible for the product's code, quality,
compatibility, functional support, and intellectual-property licensing.


## 2. Distribution models

Two licensing backends are supported. **OpenKey** is the Nexus-native
default — it issues the license for a free product and for a paid one, and it
is what the current Nexus Commerce flow issues licenses through. **Cryptlex** is an
alternative for developers who already use it as their licensing platform,
or who prefer a dedicated third-party provider instead of the Nexus-native
one. Both do hardware-bound, node-locked activation — that isn't what
distinguishes them.

### OpenKey

The Nexus-native backend. The same issuance serves a free product and a paid
one; what changes is how the customer gets the key.

For free/open-source projects, OpenKey licenses are obtained through a **Get
Key** link provided for each integrated plugin. When the link is opened, the
user authorizes identification through their GitHub account. The verified
primary email is used to generate the license and display the key to be
entered in MCNexus. If the same user opens the link again, the key already
associated with the account is displayed.

For commercial projects, OpenKey is also what issues the license inside the
current Nexus Commerce flow — GitHub confirms identity, Stripe processes
payment, OpenKey creates or updates the license, and MailerLite delivers the
operational message. See §5.

Node-lock by machine fingerprint, the Beta/Demo/Trial/Full editions, the
offline validity window, and air-gap activation are all part of the OpenKey
licensing core, whether the product is free or paid.

A GitHub account with a verified primary email is required for the current
flow. Making GitHub an optional identity and release-source adapter is part of
the planned evolution.

### Cryptlex

An alternative backend for developers who already use Cryptlex as their
licensing platform, or who prefer a dedicated third-party licensing SaaS
instead of the Nexus-native one. Hardware-bound, node-locked activation is
not what sets it apart — OpenKey does that too (above); the difference is
that Cryptlex is an external platform some developers already run their
product on, with its own dashboard and tooling outside Nexus. MCNexus
validates and activates against a Cryptlex-issued key the same way it does
for OpenKey.

Sale and license issuance for Cryptlex-licensed products happen through your
own external commercial channel. Editions and activation limits for Cryptlex
products are configured in your own Cryptlex account, not by Nexus. A Stripe
checkout issuing a Cryptlex license automatically is on the
[roadmap](ROADMAP.md).

Commercial terms, activation limits, available editions, and support policy are defined for each product.

## 3. Integration lifecycle

The process starts by reviewing the project form and confirming what is
currently supported. We then agree on the integration profile, configure the
tenant, exchange the SDK handoff values in §7, and test a real release before
calling onboarding complete.

### 3.1. First contact

Complete the [project form in §1](#1-project-intake). We may ask follow-up
questions if the requested host, licensing profile, provider, or release
format needs a technical review.

### 3.2. File preparation

The following packaging rules apply to the current OFX integration. Other
product types must agree on supported formats during technical review. For
OFX, each version must provide one artifact for every supported operating
system. macOS accepts a `.zip` or `.pkg`; Windows requires a `.zip`. Use the
following naming convention:

```text
<Product>-macOS-<Version>.zip
<Product>-macOS-<Version>.pkg
<Product>-Windows-<Version>.zip
```

Examples:

```text
MyPlugin-macOS-1.2.0.zip
MyPlugin-macOS-1.2.0.pkg
MyPlugin-Windows-1.2.0.zip
```

Keep the product name, platform, and version clearly identified. Avoid publishing a single file for more than one platform.

The recommended ZIP contents place the OFX bundle at the archive root:

```text
MyPlugin-macOS-1.2.0.zip
└── MyPlugin.ofx.bundle/
    └── Contents/
        └── MacOS/

MyPlugin-Windows-1.2.0.zip
└── MyPlugin.ofx.bundle/
    └── Contents/
        └── Win64/
```

Each ZIP should contain only the bundle for its platform, placed at the archive root. The bundle and OFX executable names should remain consistent between versions.

For a macOS `.pkg`, MCNexus expands the package into temporary storage and searches its payload for `.ofx.bundle` directories. It does not run package installation scripts. The bundle must be self-contained and installable by copying it into the OFX plug-ins directory; packages that depend on installer scripts are not supported.

### 3.3. Publication

Once the files are prepared, the plugin is configured in Nexus and tested in MCNexus. After publication, new versions can follow the same naming and packaging pattern.

## 4. Channels and editions

- **OpenKey:** Beta, Demo, Trial, and Full — the same four editions on a free
  or a paid project.
- **Cryptlex:** editions and activation limits are configured in your own
  Cryptlex account; Nexus does not dictate them.

Beta is exclusive to OpenKey. Demo and Trial both identify evaluation
versions — Trial is time-boxed, Demo is not — and Full identifies the
complete edition. A version must have an unambiguous identity and must not
be silently replaced by a different binary using the same version number.

## 5. Current Nexus Commerce flow

Commerce sells a product through the developer's **own Stripe account**, with
the license issued and delivered automatically.

Configured once: an **offer catalog** binding a price to a product, the payment
account, and the terms, privacy and refund URLs presented at checkout.

On every sale:

1. GitHub verifies the customer's identity and primary email;
2. the customer completes the payment through Stripe;
3. Nexus records the order, the payment event, and **which version of the terms
   the customer accepted**;
4. the license is created or updated, and the key is delivered by **one-time
   reveal** plus a transactional email;
5. the customer enters the key in MCNexus, which validates access and installs
   the corresponding artifact.

Fulfillment attempts are recorded per order, so a retried or duplicated payment
event does not issue a second license.

Cryptlex-licensed products are distributed through MCNexus with a valid
commercial key, with issuance handled in the developer's own Cryptlex account.
Cryptlex fulfillment inside this flow, and additional payment, licensing,
identity, email, and release providers, are on the [roadmap](ROADMAP.md).

Integrations must handle retries and duplicate events without issuing unintended licenses. Keys, tokens, webhook signatures, and service credentials must never be stored in public repositories.

## 6. Security and distribution

Nexus uses protected downloads for products that require access control. A license key must not be included in public URLs, logs, filenames, or error reports.

Signing and cryptographic verification of all distributed packages remain part of the planned evolution in the [Roadmap](ROADMAP.md).

## 7. NexKeyRuntime: integration and handoff

[NexKeyRuntime](https://github.com/ciqueira/NexKeyRuntime) is the public
C/C++14 SDK that a product embeds. It covers update discovery, product notices,
and offline verification of an activation certificate — on the render thread
the decision is a single atomic read, with no network, no file I/O, and no JSON
parsing.

The repository ships the public contract only: the C header, the JSON schemas
The repository publishes the public contract: the C header, JSON schemas,
integration documentation, and examples. Official compiled libraries are
distributed separately under the [binary license](https://github.com/ciqueira/NexKeyRuntime/blob/main/BINARY_LICENSE.md).
Confirm the applicable terms and access to the required platform binaries as
part of the project setup; the public source repository alone does not grant a
tenant or backend access.

### 7.1. Choose the integration profile

- **Profile A — MCNexus activates.** The customer enters or claims the license
  in MCNexus. The host activates and writes a local receipt; the product
  embeds NexKeyRuntime to verify that receipt and make the local license
  decision. This is the common profile for plugins.
- **Profile B — the product activates.** The product collects the license key
  and calls the SDK activation API itself. This needs an explicit backend and
  user-flow review before it is selected.

The SDK's update and notice handle is independent of either licensing profile.
A product can request license verification, updates/notices, or both.

### 7.2. What MCNexus returns for the integration

After the tenant and product configuration are agreed, the developer receives
the applicable project handoff values through a private channel:

- **`tenant_id`** — the exact tenant identifier to pass to the SDK.
- **`ProductData`** — the signed product configuration containing the service
  base URL and public-key keyring. It contains no signing private key and is
  safe to embed in the product, including in a public source repository.
- **`variant` / entitlement** — the exact value to pass to
  `nexkeyruntime_license_set_variant()`, for example
  `download:sample`. The value must match the entitlement configured for the
  product and the license; it is not inferred from `ProductData`.
- **Updates/notices configuration, if requested** — the exact `artifact_id`,
  service `base_url`, and agreed platform, architecture, channel, and version
  values. These are separate from the license `variant`.
- **SDK binary details, if needed** — official release/version, applicable
  platform libraries and checksums, binary license, and the matching
  integration/build instructions.
- **A tested configuration** — which profile was verified, the expected
  activation path, and the release/artifact used for the integration test.

The same `ProductData` can be reused across product variants for a tenant, but
the SDK must still receive the correct `tenant_id` and exact license
`variant` at runtime. For the update handle, use its own `artifact_id` and
release metadata as documented in the SDK guide.

Never send or embed a tenant signing private key, backend credential, or
service secret. MCNexus does not need to give a developer those secrets to
integrate the SDK.

Three things matter before planning an integration:

- **Compiled binaries.** The repository's own contents are Apache-2.0. The
  official compiled binaries have separate terms; review the binary license
  and confirm access to the required releases as part of onboarding.
- **The API is stable as of `1.0`.** An existing function, struct layout or
  result code never changes in a way that breaks an already-compiled binary:
  only additive changes ship in a `1.x`, and a breaking change would require
  `2.0`. Result codes are append-only and are never reused or renumbered.
- **Two integration profiles.** Profile A has MCNexus activate and the
  product verify locally. Profile B has the product activate through the SDK
  and requires a per-project backend and user-flow review. Neither profile is
  provisioned through self-service onboarding.

The [Roadmap](ROADMAP.md) tracks all three.

## 8. Integrated providers

Each layer below is separated by an explicit contract, so a provider is a
configuration of the platform rather than something built into it. This table
is the single source of truth for what is connected today; other pages describe
the layer, not the vendor.

| Layer | Integrated today | On the roadmap |
|---|---|---|
| Identity | GitHub OAuth | Email and magic link, without a GitHub account |
| Payment | Stripe | Lemon Squeezy, then further checkouts |
| Licensing | OpenKey (Nexus-native), Cryptlex | Keygen, LicenseSpring |
| Commerce fulfillment | OpenKey | Cryptlex |
| Transactional email | MailerLite | An additional provider under separate contracts |
| Release source | GitHub Releases; Cryptlex-hosted releases for products configured with it | S3-compatible storage, Cloudflare R2 first |

Roadmap entries are directions, not commitments to a vendor or a date — the
[Roadmap](ROADMAP.md) carries the current state of each.

## 9. Next steps

Current plugins are listed in [Discovery](DISCOVERY.md). Open-source projects can use the public suggestion form.

For commercial integrations, contact us privately at [hello@mcnexus.app](mailto:hello@mcnexus.app). Do not publish commercial models, credentials, pricing, or other confidential details through GitHub Issues.

The public integration kit, provider expansion, channel-independent
distribution, examples, and automated specifications remain on the
[Roadmap](ROADMAP.md).
