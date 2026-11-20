# DCTL to OFX Guide

[English](DCTL.md) · [Português](../../pt-BR/docs/developers/DCTL.md)

[Home](../../README.md) · [Developer Guide](../DEVELOPERS.md) · [Licensing](LICENSING.md) · [Commerce](COMMERCE.md) · [Releases](RELEASES.md) · [DCTL](DCTL.md) · [MIDI](MIDI.md)

Package `.dctl` scripts and 3D LUTs into native OpenFX (`.ofx.bundle`) plugins for macOS (Metal) and Windows (OpenCL) with the full `NexKeyRuntime` stack built in, without writing C++ code.

## 1. Overview & Included Platform Capabilities

The `NexKeyRuntime` DCTL-to-OFX pipeline compiles your color math and UI definitions into an encrypted, signed native `.ofx.bundle` plugin with zero unencrypted `.dctl` files written to disk.

Each generated `.ofx.bundle` ships ready for MCNexus distribution with every core capability active out of the box:

- **Offline licensing:** `Beta`, `Demo` (watermarked), `Trial`, and `Full` editions with node-locked verification and air-gap support.
- **Updates & in-app notices:** update discovery, vendor notices (`critical`, `recommended`, `info`), and 1-click install and rollback through the MCNexus app.
- **Physical MIDI control (`NexControl`):** DCTL parameters mapped directly to supported MIDI hardware controllers.
- **Checkout & delivery:** ready for free Discovery listing or direct Stripe sales (0% commission) with zero extra code.

The DCTL preprocessor supports all **6** standard `DEFINE_UI_PARAMS` control types:

1. `DCTLUI_SLIDER_FLOAT` (floating-point slider with min, max, default, and step)
2. `DCTLUI_VALUE_BOX` (numeric input box)
3. `DCTLUI_SLIDER_INT` (integer slider)
4. `DCTLUI_CHECK_BOX` (boolean toggle)
5. `DCTLUI_COMBO_BOX` (dropdown enum list)
6. `DCTLUI_COLOR_PICKER` (RGB color picker)

## 2. Choosing a Product Name & Unique Slug

Before packaging for distribution, pick a clear product name and a unique lowercase slug (for example, `film-print-halide`). Avoid generic names that collide with existing plugins in [Discovery](../DISCOVERY.md) and keep the same slug across GitHub Releases, `ProductData`, and OpenKey templates.

## 3. Local Packaging & Testing in the Sandbox

You can validate any `.dctl` script locally with pre-provisioned sandbox keys in [sandbox/dctl-to-ofx](https://github.com/ciqueira/NexKeyRuntime/tree/main/sandbox/dctl-to-ofx):

```bash
# macOS (Metal)
nexkeyctl package-dctl \
  --input="MyEffect.dctl" \
  --name="My Effect" \
  --runner="<path-to-macos-runner>" \
  --output="./dist" \
  --sandbox

# Windows (OpenCL)
nexkeyctl.exe package-dctl ^
  --input="MyEffect.dctl" ^
  --name="My Effect" ^
  --runner="<path-to-windows-runner>" ^
  --output=".\dist" ^
  --sandbox
```

Generated `.ofx.bundle` packages are signed and encrypted. Copy the generated `.ofx.bundle` to `/Library/OFX/Plugins/` (macOS) or `C:\Program Files\Common Files\OFX\Plugins\` (Windows) to verify watermarked `Demo` mode and clean `Full` rendering using the sandbox test keys.

## 4. Publishing Free/OSS or Commercial Releases to Discovery

1. **Free or Open-Source track (Community):** push your `.zip` / `.pkg` packages to GitHub Releases and submit the [plugin suggestion form](https://github.com/ciqueira/MCNexus/issues/new?template=plugin_suggestion.yml) to list your plugin in [Discovery](../DISCOVERY.md).
2. **Commercial track:** complete the project intake in [Developer Guide](../DEVELOPERS.md) to receive your `tenant_id` and signed `ProductData`, connect Stripe (0% platform commission), and ship updates with 1-click install and rollback through MCNexus.
