# Developer Documentation

[English](DEVELOPERS.md) · [Português](../pt-BR/docs/DEVELOPERS.md)

[Home](../README.md) · [Discovery](DISCOVERY.md) · [User Guide](USER_GUIDE.md) · [Developer Guide](DEVELOPERS.md) · [FAQ](FAQ.md) · [Roadmap](ROADMAP.md) · [Continuity](CONTINUITY.md)

This hub is the entry point for integrating products with MCNexus and the `NexKeyRuntime` SDK. Detailed technical specifications for each subsystem live in the five guides below.

## Developer Guides

- **[Licensing & Activation](developers/LICENSING.md):** OpenKey and Cryptlex backends, embedding `NexKeyRuntime` (`ABI 1.0`), snapshot fields, offline grace window, air-gap files (`.req` / `.lic`), and 4-slot signing keyrings.
- **[Commerce & Fulfillment](developers/COMMERCE.md):** direct Stripe checkout (0% commission), Email OTP / Google / GitHub buyer identity, idempotent fulfillment, in-place edition upgrade (`Demo`/`Trial` to `Full`), and legal acceptance.
- **[Releases, Rollback & Notices](developers/RELEASES.md):** GitHub Releases packaging, `release-manifest.json`, signed proxy delivery, streaming `SHA256` verification, `stable` vs. `beta` channels, 1-click rollback, and `Updates & Notices`.
- **[DCTL to OFX Guide](developers/DCTL.md):** packaging `.dctl` scripts and 3D LUTs into native Metal/OpenCL `.ofx.bundle` plugins without writing C++, naming/slug conventions, sandbox validation, and publishing free or commercial releases to Discovery.
- **[Hardware MIDI Control (NexControl)](developers/MIDI.md):** integrating `MCNexControl.h`, built-in vs. custom Tier 1 JSON profiles, tray controls, and active-node focus behavior.

## 1. Project intake

Integrations are reviewed and provisioned per project. To start an integration, copy the form below and send it to [hello@mcnexus.app](mailto:hello@mcnexus.app) (or use the [plugin suggestion form](https://github.com/ciqueira/MCNexus/issues/new?template=plugin_suggestion.yml) for free/open-source projects).

### Copyable project form

```text
Project / Plugin Name:
Developer / Brand Name:
Contact Email:
Repository or Website URL:
Distribution Tier: Free (Community) / Commercial Start / Commercial Pro / Commercial SDK
SDK Embedding Mode: Plugin + MCNexus App / Custom Launcher / Standalone App
Licensing Backend: OpenKey (native) / Cryptlex / Undecided
Target Platforms: macOS Universal / Windows x64 / Windows ARM
Release Source: Public GitHub Releases / Private GitHub Releases
Checkout (if commercial): Stripe Direct / External Store
Support Email & Legal URLs (Terms, Privacy, Refund):
```

## 2. Where the SDK embeds

`NexKeyRuntime` is a single native C/C++ core (`ABI 1.0`) designed to operate across three embedding models:

1. **Inside the plugin (hot path):** the OFX/DCTL plugin links `NexKeyRuntime` for `< 1 ns` atomic render decisions, edition checks, in-app notices, and optional `NexControl` MIDI binding, while the MCNexus desktop app handles activation, download, 1-click updates, and rollback in the background.
2. **Inside your own distribution app or launcher:** your custom installer or hub embeds the SDK to activate seats, batch-sync licenses, query releases, and display notices under your own UI.
3. **Inside standalone native software:** desktop applications, CLI tools (`nexkeyctl`), and headless render-farm nodes embed the SDK end to end for online or air-gap activation with no external client app in the loop.

For free Community plugins, embedding the SDK is optional when distributing compiled binaries through MCNexus.

## 3. Integrated providers

Each platform layer is isolated behind an explicit contract:

| Layer | Available in production today | On the roadmap |
|---|---|---|
| **Identity** | Email OTP verification, Google OAuth, GitHub OAuth | Microsoft, Apple Sign-In |
| **Licensing** | OpenKey (native), Cryptlex | Custom external license engines |
| **Checkout** | Stripe Direct (0% platform commission) | Lemon Squeezy, Shopify, Pix |
| **Release source** | Public or private GitHub Releases | Cloudflare R2, AWS S3, GitLab Releases |
| **Transactional email** | MailerLite (Commerce) | Custom SMTP relays |

## 4. Next steps

1. Test locally in the [NexKeyRuntime SDK Sandbox](https://github.com/ciqueira/NexKeyRuntime/tree/main/sandbox) (with pre-provisioned keys, reference OFX plugin, DCTL packager, and `nexkeyctl` CLI).
2. Review [Tenant Legal Guide](TENANT_LEGAL_GUIDE.md) if publishing a commercial product.
3. Send the completed intake form to [hello@mcnexus.app](mailto:hello@mcnexus.app).
