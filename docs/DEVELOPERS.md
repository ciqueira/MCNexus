# Developer Documentation

[English](DEVELOPERS.md) · [Português](../pt-BR/docs/DEVELOPERS.md)

[Home](../README.md) · [Discovery](DISCOVERY.md) · [User Guide](USER_GUIDE.md) · [FAQ](FAQ.md) · [Roadmap](ROADMAP.md) · [Continuity](CONTINUITY.md)

Nexus provides infrastructure for licensing, distributing, and updating native
software that has to keep working offline. This page describes the current
integration model, expected project requirements, and the responsibilities
shared by the platform and the developer.

The integration documented here is the OFX one, which is the only kind of software
running in production. The licensing core is not tied to OFX, but no other host
or application type is offered as a configured integration yet — see the
[Roadmap](ROADMAP.md).

> **Documentation status:** integration is currently reviewed and configured per project. There is no public onboarding API or fully self-service publishing process at this time. Internal formats, credentials, and security details are not documented publicly.

## 1. Who integration is for

Nexus currently supports OFX projects that need one or more of these
capabilities:

- standardized installation on macOS and Windows;
- release delivery and update notifications;
- licensing through OpenKey, the Nexus-native backend — the same license
  issuance for a free product and a paid one;
- Cryptlex support, as an alternative licensing backend;
- Beta, Demo, Trial, and Full editions for OpenKey;
- rollback to previously published versions;
- automation between checkout, license issuance, and transactional communication.

The developer remains responsible for the plugin's code, quality, compatibility, functional support, and intellectual-property licensing.

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

The process starts with a conversation about the plugin, available platforms, and distribution model. We then prepare the files and configure publication in Nexus.

### 3.1. First contact

Share the plugin name, supported platforms, whether the product is free or
commercial, and which licensing backend it will use — OpenKey or Cryptlex.

### 3.2. File preparation

Each version must provide one `.zip` file for every supported operating system. Use the following convention:

```text
<Product>-macOS-<Version>.zip
<Product>-Windows-<Version>.zip
```

Examples:

```text
MyPlugin-macOS-1.2.0.zip
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

## 7. Client SDK (NexKeyRuntime)

[NexKeyRuntime](https://github.com/ciqueira/NexKeyRuntime) is the public
C/C++14 SDK that a product embeds. It covers update discovery, product notices,
and offline verification of an activation certificate — on the render thread
the decision is a single atomic read, with no network, no file I/O, and no JSON
parsing.

The repository ships the public contract only: the C header, the JSON schemas
for ProductData and the activation certificate, integration documentation, and
examples. Compiled static libraries for macOS (universal) and Windows x64 are
published as releases with checksums.

Three things matter before planning an integration:

- **Compiled binaries.** The repository's own contents are Apache-2.0 and
  usable today. Access to the compiled releases is arranged with each
  developer, under the binary license; self-service onboarding is on the
  [roadmap](ROADMAP.md).
- **The API is stable as of `1.0`.** An existing function, struct layout or
  result code never changes in a way that breaks an already-compiled binary:
  only additive changes ship in a `1.x`, and a breaking change would require
  `2.0`. Result codes are append-only and are never reused or renumbered.
- **Two integration profiles.** In Profile A the host application (MCNexus)
  activates the license and the plugin verifies it locally. In Profile B the
  product activates and synchronizes on its own, without MCNexus; the SDK
  implements it and the gateway routes are deployed. Setup for either goes
  through a per-project conversation rather than self-service onboarding.

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
