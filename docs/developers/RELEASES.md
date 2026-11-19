# Releases, Rollback & Notices

[English](RELEASES.md) · [Português](../../pt-BR/docs/developers/RELEASES.md)

[Home](../../README.md) · [Developer Guide](../DEVELOPERS.md) · [Licensing](LICENSING.md) · [Commerce](COMMERCE.md) · [Releases](RELEASES.md) · [DCTL](DCTL.md) · [MIDI](MIDI.md)

## 1. File Preparation & Release Manifest

Releases are published as compiled platform packages (`.zip` or `.pkg` containing the `.ofx.bundle`) on public or private **GitHub Releases** (support for Cloudflare R2, AWS S3, and GitLab Releases is on the roadmap). Each release can include a structured `release-manifest.json` declaring:

- Target OS and architecture (`macos-arm64`, `macos-x86_64`, `macos-universal`, `windows-x64`, `windows-arm64`).
- Minimum MCNexus client version and per-variant download entitlements.
- Published `SHA256` digest per asset.

## 2. Protected Proxy Delivery & Streaming SHA256 Verification

The MCNexus app never receives the raw GitHub or storage URL. Download requests are resolved through the MCNexus proxy using short-lived signed tokens. Before installing, the desktop app verifies the streaming `SHA256` digest against the manifest and discards any mismatched file.

## 3. Release Channels (stable vs. beta) & 1-Click Rollback

The server enforces channel separation at download resolution: `Full`, `Trial`, and `Demo` licenses receive `stable` releases only, while `Beta` keys receive `beta` prereleases. In the MCNexus desktop app, end users can update in 1 click or select any prior published release to perform an instant rollback.

## 4. Updates & In-App Notices

Both plugins and standalone apps can query `NexKeyRuntimeHandle` for updates and vendor notices via non-blocking cached polling without blocking the host UI or render thread.

- **Severities:** `critical`, `recommended`, and `info`.
- **Targeting:** filter by host application, plugin version range, OS, and CPU architecture, with optional campaign start/expiration windows.
- **Localization & Security:** notices support bilingual `EN` and `pt-BR` copy and are strictly **plain text** (no HTML, arbitrary Markdown, or executable scripts). See [NexKeyRuntime UPDATES_AND_NOTICES.md](https://github.com/ciqueira/NexKeyRuntime/blob/main/docs/UPDATES_AND_NOTICES.md).
