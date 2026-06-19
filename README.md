<img src="images/Nexus-Brand.png" alt="MCNexus" width="360">

---

[English](README.md) · [Português](pt-BR/README.md)

**Install, activate, and maintain OFX plugins in one place.**

MCNexus centralizes OFX plugin installation, licensing, and version control on macOS and Windows. For post-production workstations, it reduces manual steps and simplifies updates and rollback. For developers, it provides standardized infrastructure for distribution, licensing, and release delivery.

<table>
  <tr>
    <td width="65%">
      <img src="images/screen_app.png" alt="MCNexus application" width="100%">
    </td>
    <td>
      <a href="https://github.com/ciqueira/MCNexus/releases/download/windows-latest/MCNexus-Setup-Windows.exe">
        <img src="https://img.shields.io/badge/Download_for-Windows-0078D4?style=for-the-badge" alt="Download for Windows">
      </a>
      <br><br>
      <a href="https://github.com/ciqueira/MCNexus/releases/download/macos-latest/MCNexus-macOS.dmg">
        <img src="https://img.shields.io/badge/Download_for-macOS-000000?style=for-the-badge" alt="Download for macOS">
      </a>
    </td>
  </tr>
</table>

> **Installation notice:** current Windows builds are not code-signed, and current macOS builds are not signed with an Apple Developer ID certificate or notarized by Apple. Microsoft Defender SmartScreen or macOS Gatekeeper may display a warning during installation. Official builds are distributed exclusively through this repository.

## Discover Plugins

Explore the OFX plugins already integrated with MCNexus.

[View integrated plugins](docs/DISCOVERY.md) · [Suggest a plugin](https://github.com/ciqueira/MCNexus/issues/new?template=plugin_suggestion.yml)

## For Users

MCNexus manages the lifecycle of plugins installed on a workstation, from initial activation to installing a previous version.

- **Automatic installation:** downloads and installs OFX files in the native directory defined by the operating system.
- **Updates and rollback:** identifies published versions and allows an available update or previous version to be installed.
- **Independent actions:** activating a license, deactivating it, removing the local key, and removing plugin files are separate operations.
- **Moving between computers:** when the previous computer is accessible, deactivate the license there before activating it on another machine. Remote releases and activation-limit adjustments still require support.

[Start with the User Guide](docs/USER_GUIDE.md)

## For Developers

MCNexus provides a distribution pipeline for commercial and open-source OFX projects.

- **Flexible distribution:** commercial licensing through Cryptlex or open distribution through OpenKey.
- **Transaction automation:** Stripe payment processing with automated license generation and credential delivery through MailerLite.
- **Release management:** macOS and Windows artifacts, GitHub Releases integration, Beta, Demo, and Full channels for OpenKey, Demo and Full editions for commercial distribution, protected downloads, and update notifications.

[Understand developer integration](docs/DEVELOPERS.md)

## Application Compatibility

- **macOS:** macOS 15 or later, including Apple Silicon and supported Intel Macs.
- **Windows:** Windows 10/11 x64, with Windows 11 ARM support through x64 emulation.
- **Linux:** planned.

## Project

MCNexus combines software engineering with practical experience in audiovisual post-production. Developed independently by [Magno Ciqueira](https://www.linkedin.com/in/ciqueira/) ([Instagram](https://www.instagram.com/magnociqueira/)), the project aims to reduce technical friction and provide reliable infrastructure for commercial and open-source tools.

## Documentation

- [Discovery](docs/DISCOVERY.md)
- [User Guide](docs/USER_GUIDE.md)
- [Developer Documentation](docs/DEVELOPERS.md)
- [Frequently Asked Questions](docs/FAQ.md)
- [Roadmap](docs/ROADMAP.md)
- [Terms of Use](TERMS.md)
- [Privacy Policy](PRIVACY.md)

## Support

Use the [GitHub support forms](https://github.com/ciqueira/MCNexus/issues/new/choose) for technical problems, activation questions, bug reports, and suggestions. Include the operating-system version, MCNexus version, affected plugin, and available diagnostics.

GitHub Issues are public and indexed by search engines. Do not publish a complete license key or personal data. Privacy requests must be sent to [nexus@magnociqueira.com.br](mailto:nexus@magnociqueira.com.br).
