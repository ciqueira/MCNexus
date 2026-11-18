# Licensing & Activation

[English](LICENSING.md) · [Português](../../pt-BR/docs/developers/LICENSING.md)

[Home](../../README.md) · [Developer Guide](../DEVELOPERS.md) · [Licensing](LICENSING.md) · [Commerce](COMMERCE.md) · [Releases](RELEASES.md) · [DCTL](DCTL.md) · [MIDI](MIDI.md)

## 1. Licensing Models (OpenKey & Cryptlex)

MCNexus supports two hardware-bound, node-locked licensing backends through the same client experience:

- **OpenKey (native):** issues free and commercial keys (`Beta`, `Demo`, `Trial`, and `Full`), enforces configurable seat limits per license, supports self-service machine deactivation, and connects directly to Nexus Commerce for automatic in-place upgrades.
- **Cryptlex:** alternative backend for developers who already operate Cryptlex. Products are sold and issued through the developer's own channel while MCNexus handles desktop installation, updates, and rollback.

## 2. NexKeyRuntime Integration & Embedding Modes

`NexKeyRuntime` is a native C/C++ library with a stable C ABI (`ABI 1.0`, forward-compatible across `1.x`) for macOS universal (`arm64` + `x86_64`) and Windows (`x64`, `x86`, `arm64`). Public headers, JSON Schemas, examples, and binaries (`BINARY_LICENSE.md`) are published in [ciqueira/NexKeyRuntime](https://github.com/ciqueira/NexKeyRuntime).

1. **Inside an OFX/DCTL plugin:** call `nexkeyruntime_license_load_local()` at plugin load and `nexkeyruntime_license_render_decision()` inside the render callback (atomic `< 1 ns` memory read, zero locks, zero network, zero disk I/O).
2. **Inside a custom launcher or standalone app:** call `nexkeyruntime_license_activate()`, `nexkeyruntime_license_request_sync()`, and `nexkeyruntime_license_deactivate()` on background worker threads, and call `nexkeyruntime_license_set_headless()` for render-farm or CLI processes without a GUI.

## 3. Handoff & Snapshot Contract

After project intake, MCNexus provisions your `tenant_id`, signing keyring, and a signed `ProductData` blob (public keyring + gateway base URL, safe to commit to public repositories).

- **C Snapshot (`NexKeyRuntimeLicenseSnapshot` in `nexkeyruntime.h`):** exposes `status`, `decision`, `last_error`, `activated_at`, `expires_at` (`0` for perpetual), `days_remaining` (`-1` for perpetual), `sync_after`, `offline_valid_until`, `last_synced_at`, `activations_used`, `max_activations`, `edition`, and `edition_enum` (`NEXKEYRUNTIME_EDITION_BETA`, `DEMO`, `TRIAL`, `FULL`).
- **Edition lifecycle:** `Beta` is isolated to prerelease testers and blocked from checkout issuance; `Demo` has no expiration and lets plugins read `edition_enum` to apply watermarks or feature caps; `Trial` starts its countdown on first activation based on the backend `trial_days` offer parameter; `Full` unlocks perpetual or subscription access.

## 4. Offline Window & Air-Gap Files (.req / .lic)

Every signed Ed25519 activation certificate carries two independent deadlines in its JSON payload (`syncAfter` and `offlineValidUntil`):

- **`syncAfter`** (`sync_after` in C): when background renewal starts attempting to refresh the certificate (default 24 hours).
- **`offlineValidUntil`** (`offline_valid_until` in C): the hard offline limit enforced locally by the SDK (default 30 days, configurable up to 365 days). The issuer guarantees the offline window always covers multiple renewal attempts.

For workstations with zero network access, export an activation request (`.req`), sign it via the gateway or recovery authority into a `.lic` certificate, and import it offline. Seat release uses the same file-based deactivation proof path.

## 5. Signing Keyrings (4 Slots) & Recovery Authority

Each tenant keyring holds up to **4 public Ed25519 keys**, allowing zero-downtime key rotation without invalidating already-installed binaries. On Commercial Pro and Commercial SDK plans, developers generate and hold their own offline signing and recovery keys: the private half never touches Nexus servers, enabling emergency certificate issuance independently of Nexus infrastructure. See [Continuity & Recovery](../CONTINUITY.md).
