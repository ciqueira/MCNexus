# Hardware MIDI Control

[English](MIDI.md) · [Português](../../pt-BR/docs/developers/MIDI.md)

[Home](../../README.md) · [Developer Guide](../DEVELOPERS.md) · [Licensing](LICENSING.md) · [Commerce](COMMERCE.md) · [Releases](RELEASES.md) · [DCTL](DCTL.md) · [MIDI](MIDI.md)

`NexControl` connects physical MIDI hardware controllers directly to OpenFX plugin parameters, with no mouse capture and zero dependence on screen resolution or window layout.

## 1. How It Works

The MCNexus desktop app hosts the MIDI hub, translates incoming hardware messages using device profiles, and dispatches updates directly to active OFX plugin parameters over a local low-latency channel. Control stays stable when resizing panels, switching monitors, or changing display scaling, without requiring OS Accessibility permissions.

## 2. Integrating MCNexControl.h in OFX Plugins

Include `MCNexControl.h` from `NexKeyRuntime`, register your plugin's ordered parameter table, and bind the host parameter-update callback so physical encoder turns and button clicks update the Inspector and trigger a clean viewer refresh. `MCNexControl.h` also supports parameter grouping, virtual bank pagination for controllers with fewer encoders, and native host undo grouping for hardware edits. See [NexKeyRuntime NEXCONTROL_INTEGRATION.md](https://github.com/ciqueira/NexKeyRuntime/blob/main/docs/NEXCONTROL_INTEGRATION.md) and `examples/06-nexcontrol-ofx`.

## 3. Desktop Tray Status & Active-Node Focus

MCNexus shows controller status, the active plugin, live **Knob Activity** diagnostics (channel, bank, and encoder mode), and pause/resume controls in the macOS menu bar and Windows system tray.

- **Per-device MIDI port selection:** enable or release individual MIDI controllers from the tray or menu bar (and see when a port is `Busy` in another app) so MCNexus coexists cleanly with other MIDI software. On first launch, MCNexus selects the first available compatible controller automatically and preserves manual choices across launches.
- **Inspector-scoped routing:** updates are sent only when a compatible OFX node is focused in the Inspector (**macOS** and **Windows**).
- **Silent on native nodes:** on native Resolve nodes, NexControl stays idle in the background and does not conflict with other MIDI tools.
- **Requirement:** active-node focus tracking requires **DaVinci Resolve Studio**.

## 4. Supported Controllers & Device Profiles

NexControl resolves device profiles in three tiers:

1. **Tier 1 (User custom directory):** `.json` profile files placed in `~/Library/Application Support/MCNexus/profiles` (macOS), `%APPDATA%\MCNexus\profiles` (Windows), or the path set by `MCNEXUS_PROFILES_DIR`. Tier 1 profiles override built-in mappings when matched.
2. **Tier 2 (Built-in profiles, automatic):** built-in controller profiles ship inside the desktop app and load automatically out of the box.
3. **Tier 3 (Generic fallback):** any other MIDI controller defaults to **`Auto-Detect`** encoder mode, with a **Generic Encoder Mode** submenu (`Auto-Detect`, `Absolute (0-127)`, `Two's Complement`, `Binary Offset 64`, `Sign-Magnitude / Mackie`) saved per preference unless a Tier 1 profile is installed.

### Supported Hardware & Profile Downloads

| Controller | Integration | Controls & Setup Notes | Profile |
| :--- | :--- | :--- | :--- |
| **DJ TechTools Midi Fighter Twister** | Built-in (Tier 2) | 16 infinite encoders across 4 banks with push-to-reset. Plug-and-play. | Built-in |
| **Behringer X-TOUCH MINI** | Built-in (Tier 2) + Extended Tier 1 | 8 infinite encoders across Layer A and Layer B with push-to-reset. Works out of the box in factory Standard Mode and MC Mode; the downloadable profile adds extended relative channel support. | [Download X-TOUCH MINI profile](../../site/assets/profiles/behringer_xtouch_mini.json) |
| **Intech Studio EN16 + BU16** | Tier 1 Profile | 16 infinite encoders with push-to-reset plus 16 tactile buttons over a single `Intech Studio: Grid` USB connection. Works with factory 4-page firmware or custom Grid layouts. | [Download EN16 + BU16 profile](../../site/assets/profiles/intech_studio_grid.json) |
| **Intech Studio EN16 (Standalone)** | Tier 1 Profile | Single-module 16-encoder setup using the `Grid` profile. Works with factory 4-page firmware or solo layouts where encoder clicks trigger button actions. | [Download EN16 profile](../../site/assets/profiles/intech_studio_grid.json) |
| **Loupedeck (CT, Live, Live S, MX Creative Console)** | Tier 1 Profile (manual mapping) | Rotary dials (plus CT Control Wheel) and buttons through the third-party MIDI Plugin included in the Loupedeck / Logi Options+ software. Requires a virtual MIDI port containing `Loupedeck` in its name and one-time manual dial mapping (see setup below). | [Download Loupedeck profile](../../site/assets/profiles/loupedeck_midi.json) |
| **Arturia BeatStep** | Tier 1 Profile | 16 infinite encoders plus 16 pads mapped to parameter reset. | [Download BeatStep profile](../../site/assets/profiles/arturia_beatstep.json) |
| **Korg nanoKONTROL Studio** | Tier 1 Profile | 8 infinite encoders plus button clicks for parameter reset over USB or Bluetooth MIDI. | [Download nanoKONTROL Studio profile](../../site/assets/profiles/korg_nanokontrol_studio.json) |
| **Elgato Stream Deck +** | Coming soon ([roadmap*](../ROADMAP.md)) | 4 rotary dials with push click, 8 LCD keys, and Touch Strip via dedicated Stream Deck plugin bridge. | Coming soon |

### Quick Installation & Setup Instructions

#### 1. Installing a Tier 1 Profile

Download the profile for your controller from the table above and save it in `~/Library/Application Support/MCNexus/profiles` (macOS) or `%APPDATA%\MCNexus\profiles` (Windows). Then open the MCNexus menu bar or system tray icon and click **Reload Custom Profiles**.

#### 2. Intech Studio (EN16 + BU16 or EN16 Standalone)

After installing the profile above, connect your Grid controller. Both factory 4-page firmware and custom Grid layouts work automatically without extra configuration.

#### 3. Loupedeck (Manual Mapping in the Loupedeck MIDI Plugin)

The MIDI Plugin is provided by Loupedeck / Logitech inside their own software. MCNexus does not install or configure it, and no ready-made Loupedeck preset is published yet, so map the dials once by hand:

- **macOS:** Open *Audio MIDI Setup*, show *MIDI Studio*, enable **IAC Driver**, and name a bus containing `Loupedeck` (for example, `Loupedeck IAC Bus`).
- **Windows:** Create a virtual MIDI port in **loopMIDI** containing `Loupedeck` in its name (for example, `Loupedeck Port`).
- **Dials:** In the Loupedeck software, assign each dial a MIDI Plugin rotation action that sends `Control Change` on Channel 1, starting at `CC 1` for the first dial up to `CC 32`.
- **Dial presses (reset to default):** Assign a MIDI Plugin action that sends `Note On` with the same number as the dial (`Note On 1` for the dial on `CC 1`).
- **Check:** Focus a NexControl-enabled plugin in the Inspector and turn a dial. The MCNexus menu bar or tray shows the last control received; if nothing appears, confirm the virtual port is selected in the MIDI Plugin.
