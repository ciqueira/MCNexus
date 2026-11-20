# Frequently Asked Questions

[English](FAQ.md) · [Português](../pt-BR/docs/FAQ.md)

[Home](../README.md) · [Discovery](DISCOVERY.md) · [User Guide](USER_GUIDE.md) · [Developers](DEVELOPERS.md) · [Roadmap](ROADMAP.md) · [Continuity](CONTINUITY.md)

## For End Users

### How does MCNexus install plugins?

The installed version of MCNexus places OFX files in the native directory used by editing and color-grading applications (`C:\Program Files\Common Files\OFX\Plugins` on Windows and `/Library/OFX/Plugins` on macOS).

### How do I obtain an OpenKey license?

Use the plugin's **Get Key** link in [Discovery](DISCOVERY.md) or through its official channel. You can authenticate with a **verified email code**, a **Google account**, or a **GitHub account**. If a license has already been generated for that identity, the same link displays the existing key again.

### Can I move a license to another computer?

All licenses use hardware-bound, node-locked activation. If the previous computer is accessible, deactivate the license there before activating it on the new computer. Removing the local key or plugin files alone does not release the activation.

If the previous computer was lost, reformatted, or is no longer accessible, use the [activation problem form](https://github.com/ciqueira/MCNexus/issues/new?template=activation_problem.yml) to request an activation review. Never publish the complete key.

### Can I use the same license on two workstations at once?

This depends on the activation limit assigned to the purchased license. Nexus does not automatically increase that limit. If all activations are occupied, deactivate an accessible installation or request support.

### How do update notifications and rollback work?

MCNexus checks available releases and displays a notification when it finds a compatible update. Installation requires user confirmation. To roll back, open the plugin release history in MCNexus and select the required version; the application replaces the plugin files automatically.

### What is the difference between deactivating a license, removing a key, and removing a plugin?

- **Deactivate license:** ends the activation associated with that machine when the operation is available.
- **Remove key:** deletes the locally stored credential without necessarily removing plugin files.
- **Remove plugin:** deletes installed OFX files without necessarily releasing the remote activation.

Read the [User Guide](USER_GUIDE.md) before changing computers or reinstalling the operating system.

### How do I get technical support?

Choose the appropriate form in the [Support Center](https://github.com/ciqueira/MCNexus/issues/new/choose). Separate forms are available for application installation, plugin installation, license activation, and general support.

> **Important:** Nexus provides support for installation, activation, updates, and removal. Problems with how a plugin functions should be reported to its developer. If you are unsure, we can help identify the correct support channel.

GitHub Issues are public and indexed by search engines. Do not publish personal data or a complete license key.

### Does Nexus comply with data-protection laws?

Nexus processes only the data required for licensing, product delivery, security, and support. See the [Privacy Policy](../PRIVACY.md) for complete information. For personal-data requests, write to [hello@mcnexus.app](mailto:hello@mcnexus.app).

---

## For Developers

### Where can I embed the NexKeyRuntime SDK?

`NexKeyRuntime` (`ABI 1.0`) is a single native C/C++ core that can be embedded in three ways: inside an OFX/DCTL plugin (with the MCNexus desktop app handling activation and updates in the background), inside your own custom launcher or installer, or directly inside a standalone native application or headless render-farm node with no MCNexus app in the loop. See [Licensing & Activation](developers/LICENSING.md).

### Do I have to pay upfront or open-source my plugin?

No. The **Community** plan is free whenever you do not charge end users, and it accepts both closed-source compiled binaries and open-source projects with no SDK requirement. For paid products, **Commercial Start** includes unlimited `Beta`, `Demo`, and `Trial` editions plus your first **10 `Full` activations free** before the flat monthly plan begins. See [NexKeyRuntime BINARY_LICENSE](https://github.com/ciqueira/NexKeyRuntime/blob/main/BINARY_LICENSE.md).

### How are purchases and licenses connected?

Stripe processes payments directly on the developer's own Stripe account with **0% platform commission**. After confirmation, Nexus issues or upgrades the license (automatically promoting `Demo` or `Trial` keys to `Full` in place when the buyer uses the same verified email), records auditable legal acceptance, and sends the key via transactional email. See [Commerce & Fulfillment](developers/COMMERCE.md).

### Which release channels and editions are supported?

OpenKey supports four editions (`Beta`, `Demo`, `Trial`, and `Full`) and separates `stable` releases from `beta` prereleases on the server. Commercial distribution uses `Demo`, `Trial`, and `Full` editions (`Beta` keys are blocked from checkout issuance). See [Releases, Rollback & Notices](developers/RELEASES.md).

### What is the difference between OpenKey and Cryptlex?

OpenKey is the Nexus-native licensing backend, handling both free and commercial products across the same client experience. Cryptlex is an alternative backend for developers who already use it; Cryptlex products are sold and issued through the developer's own channel, while issuing Cryptlex licenses directly through Nexus Commerce is on the [roadmap](ROADMAP.md).

### Can I distribute DCTLs as OFX plugins or support physical MIDI controllers?

Yes. `NexKeyRuntime` includes **DCTL-to-OFX** packaging (converting `.dctl` scripts and 3D LUTs into native Metal/OpenCL `.ofx.bundle` plugins without writing C++) and **NexControl** for direct physical MIDI parameter mapping without mouse capture or resolution-dependent UI automation. See [DCTL to OFX](developers/DCTL.md) and [MIDI Control](developers/MIDI.md).

### Can I keep control over signing keys and continuity?

Yes. On Pro and SDK plans, developers generate and hold their own offline signing and recovery keys (4-slot keyring with zero-downtime key rotation), and existing activated workstations continue running offline during any backend interruption. See [Continuity & Recovery](CONTINUITY.md).
