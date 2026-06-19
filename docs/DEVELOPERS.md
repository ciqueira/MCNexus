# Developer Documentation

[English](DEVELOPERS.md) · [Português](../pt-BR/docs/DEVELOPERS.md)

[Home](../README.md) · [Discovery](DISCOVERY.md) · [User Guide](USER_GUIDE.md) · [FAQ](FAQ.md) · [Roadmap](ROADMAP.md)

MCNexus provides infrastructure for licensing, publishing, and distributing OFX plugins. This page describes the current integration model, expected project requirements, and the responsibilities shared by the platform and plugin developer.

> **Documentation status:** integration is currently reviewed and configured per project. There is no public onboarding API or fully self-service publishing process at this time. Internal formats, credentials, and security details are not documented publicly.

## 1. Who integration is for

MCNexus supports OFX projects that need one or more of these capabilities:

- standardized installation on macOS and Windows;
- release delivery and update notifications;
- open-source distribution through OpenKey;
- hardware-bound commercial licensing;
- Beta, Demo, and Full channels for OpenKey;
- Demo and Full editions for commercial distribution;
- rollback to previously published versions;
- automation between checkout, license issuance, and transactional communication.

The developer remains responsible for the plugin's code, quality, compatibility, functional support, and intellectual-property licensing.

## 2. Distribution models

### OpenKey

Designed for open-source projects distributed through GitHub Releases. OpenKey licenses are obtained exclusively through a **Get Key** link provided for each integrated plugin.

When the link is opened, the user authorizes identification through their GitHub account. The verified primary email is used to generate the license and display the key to be entered in MCNexus. If the same user opens the link again, the key already associated with the account is displayed.

A GitHub account with a verified primary email is required to complete this flow.

### Commercial

Commercial plugins use Cryptlex for cryptographic validation and hardware-bound activation. Stripe or integrated checkout partners can trigger customer registration, license issuance, and transactional credential delivery.

Commercial terms, activation limits, available editions, and support policy are defined for each product.

## 3. Integration lifecycle

The process starts with a conversation about the plugin, available platforms, and distribution model. We then prepare the files and configure publication in MCNexus.

### 3.1. First contact

Share the plugin name, supported platforms, and whether distribution will use OpenKey or the commercial model.

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

Once the files are prepared, the plugin is configured and tested in MCNexus. After publication, new versions can follow the same naming and packaging pattern.

## 4. Channels and editions

The distribution models use the following options:

- **OpenKey:** Beta, Demo, and Full.
- **Commercial:** Demo and Full.

The Beta channel is exclusive to OpenKey. Demo can be used for demonstration or evaluation versions, while Full identifies the complete edition. A version must have an unambiguous identity and must not be silently replaced by a different binary using the same version number.

## 5. Automated commercial flow

A typical commercial flow works as follows:

1. the customer completes a purchase through Stripe or a checkout partner;
2. the transaction event is validated;
3. the customer and license are provisioned;
4. MailerLite or Mailchimp sends credentials and instructions;
5. the customer enters the key in MCNexus;
6. MCNexus validates access and installs the corresponding artifact.

Integrations must handle retries and duplicate events without issuing unintended licenses. Keys, tokens, webhook signatures, and service credentials must never be stored in public repositories.

## 6. Security and distribution

MCNexus uses protected downloads for products that require access control. A license key must not be included in public URLs, logs, filenames, or error reports.

Signing and cryptographic verification of all distributed packages remain part of the planned evolution in the [Roadmap](ROADMAP.md).

## 7. Current integrations

- **Payments:** Stripe and checkout partners.
- **Licensing:** Cryptlex and OpenKey.
- **Transactional email:** MailerLite and Mailchimp.
- **Releases:** GitHub Releases.

## 8. Next steps

Current plugins are listed in [Discovery](DISCOVERY.md). Open-source projects can use the public suggestion form.

For commercial integrations, contact us privately at [nexus@magnociqueira.com.br](mailto:nexus@magnociqueira.com.br). Do not publish commercial models, credentials, pricing, or other confidential details through GitHub Issues.

The public integration kit, examples, and automated specifications remain on the [Roadmap](ROADMAP.md).
