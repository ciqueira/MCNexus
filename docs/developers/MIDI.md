# Hardware MIDI Control (NexControl)

[English](MIDI.md) · [Português](../../pt-BR/docs/developers/MIDI.md)

[Home](../../README.md) · [Developer Guide](../DEVELOPERS.md) · [Licensing](LICENSING.md) · [Commerce](COMMERCE.md) · [Releases](RELEASES.md) · [DCTL](DCTL.md) · [MIDI](MIDI.md)

`NexControl` connects physical MIDI hardware controllers directly to OpenFX plugin parameters with low-latency local sync without requiring OS Accessibility permissions.

## 1. How NexControl Works (Zero Accessibility Permissions)

The MCNexus desktop app hosts the MIDI hub, translates incoming CC and Note messages using device profiles, and dispatches parameter updates directly to active OFX plugin instances over a local low-latency channel. End users do not have to grant macOS Accessibility or UI-automation permissions.

## 2. Integrating MCNexControl.h in OFX Plugins

Include `MCNexControl.h` from `NexKeyRuntime`, register your plugin's ordered parameter table, and bind the host parameter-update callback so physical encoder turns and button clicks update the Inspector and trigger a clean viewer refresh. See [NexKeyRuntime NEXCONTROL_INTEGRATION.md](https://github.com/ciqueira/NexKeyRuntime/blob/main/docs/NEXCONTROL_INTEGRATION.md) and `examples/06-nexcontrol-ofx`.

## 3. Built-In Profiles vs. Custom User Profiles

NexControl resolves device profiles in three tiers:

1. **Tier 1 (User custom JSON directory):** `.json` files placed in `~/Library/Application Support/MCNexus/profiles` (macOS), `%APPDATA%\MCNexus\profiles` (Windows), or the path set by `MCNEXUS_PROFILES_DIR`. After adding or editing a file, click **Reload Custom Profiles** in the MCNexus menu bar or system tray.
2. **Tier 2 (Built-in binary profiles, automatic):** built-in controller profiles are embedded directly in the binary and load automatically out of the box: **Midi Fighter Twister** and **Behringer X-TOUCH MINI**.
3. **Tier 3 (Generic fallback):** any other MIDI controller falls back to standard relative CC mapping (`twos_complement` or `binary_offset_64`) unless a Tier 1 JSON profile is installed.

### Reference JSON Profiles (Install in Tier 1 Folder)

Use the templates below as starting points in your Tier 1 profiles folder for **Arturia BeatStep** and **Korg nanoKONTROL Studio** (matching `schemas/midi-device-profile.schema.json`):

```json
{
  "profile_version": 1,
  "vendor": "Arturia",
  "model": "BeatStep",
  "match_port_name": "BeatStep",
  "rotation_bindings": [
    {
      "bank": 1,
      "midi_channel": -1,
      "encoder_mode": "twos_complement",
      "step_sensitivity": 0.01,
      "cc_start": 20,
      "cc_end": 35,
      "param_offset": 0
    }
  ],
  "click_bindings": [
    {
      "type": "note_on",
      "midi_channel": -1,
      "index_start": 36,
      "index_end": 51,
      "param_offset": 0,
      "action": "reset_default"
    }
  ]
}
```

```json
{
  "profile_version": 1,
  "vendor": "Korg",
  "model": "nanoKONTROL Studio",
  "match_port_name": "nanoKONTROL Studio",
  "rotation_bindings": [
    {
      "bank": 1,
      "midi_channel": -1,
      "encoder_mode": "twos_complement",
      "step_sensitivity": 0.01,
      "cc_start": 16,
      "cc_end": 23,
      "param_offset": 0
    }
  ],
  "click_bindings": [
    {
      "type": "cc_value",
      "midi_channel": -1,
      "index_start": 24,
      "index_end": 31,
      "param_offset": 0,
      "trigger_values": [127],
      "action": "reset_default"
    },
    {
      "type": "note_on",
      "midi_channel": -1,
      "index_start": 24,
      "index_end": 31,
      "param_offset": 0,
      "action": "reset_default"
    }
  ]
}
```

## 4. Desktop Tray Status & Active-Node Focus

MCNexus displays live controller connection status, active plugin name, and hub pause/resume controls in the macOS menu bar (`NSStatusBar`) and Windows system tray (`TrayIcon`). Automatic active-node focus tracking operates on both **macOS** and **Windows**, routing physical turns exclusively to the plugin node focused in the Inspector without requiring OS Accessibility permissions.
