<img src="images/Nexus-Brand.png" alt="MCNexus" width="360">

---

[English](README.md) · [Português](pt-BR/README.md)

**Licensing, distribution, and maintenance for OFX plugins.**

Nexus provides infrastructure for publishing, licensing, and distributing OFX
plugins. MCNexus is the macOS and Windows application used to activate
licenses, install plugins, check for updates, install previous versions, and
perform rollback.

Developer integrations are configured per project. The current platform
supports OpenKey and Cryptlex for licensing, releases hosted on GitHub or
Cryptlex according to the integration, and a controlled Commerce flow using
GitHub, Stripe, OpenKey, and MailerLite. Additional providers and public
self-service onboarding remain [roadmap work](docs/ROADMAP.md).

<table>
  <tr>
    <td width="65%">
      <img src="images/screen_app.png" alt="MCNexus application" width="100%">
    </td>
    <td>
      <a href="https://apps.microsoft.com/detail/9n1qqt1xc825">
        <img src="https://get.microsoft.com/images/en-us%20dark.svg" width="200" alt="Get it from Microsoft Store" />
      </a>
      <br>
      <small>Recommended for Windows</small>
      <br><br>
      <a href="https://github.com/ciqueira/MCNexus/releases/download/windows-latest/MCNexus-Setup-Windows.exe">
        <img src="https://img.shields.io/badge/Download_for-Windows-0078D4?style=for-the-badge" alt="Download for Windows">
      </a>
      <br>
      <a href="https://github.com/ciqueira/MCNexus/releases/download/macos-latest/MCNexus-macOS.dmg">
        <img src="https://img.shields.io/badge/Download_for-macOS-000000?style=for-the-badge" alt="Download for macOS">
      </a>
    </td>
  </tr>
</table>

The **Microsoft Store is the official and recommended installation channel for Windows**, providing code integrity and automatic background updates. The `.exe` installer remains available through GitHub as an alternative for manual installation.

> **Installation notice:** the direct Windows installer distributed through GitHub is not currently code-signed and may display a Microsoft Defender SmartScreen warning. The macOS build is not currently signed with an Apple Developer ID certificate or notarized by Apple, so Gatekeeper may also display a warning. Official downloads are available through the Microsoft Store and this repository.

## Discover Plugins

Explore the OFX plugins already integrated with Nexus.

[View integrated plugins](docs/DISCOVERY.md) · [Suggest a plugin](https://github.com/ciqueira/MCNexus/issues/new?template=plugin_suggestion.yml)

## For Users

MCNexus manages the lifecycle of plugins installed on a workstation, from initial activation to installing a previous version.

- **Automatic installation:** downloads and installs OFX files in the native directory defined by the operating system.
- **Updates and rollback:** identifies published versions and allows an available update or previous version to be installed.
- **Independent actions:** activating a license, deactivating it, removing the local key, and removing plugin files are separate operations.
- **Moving between computers:** when the previous computer is accessible, deactivate the license there before activating it on another machine. Remote releases and activation-limit adjustments still require support.

[Start with the User Guide](docs/USER_GUIDE.md)

<img src="images/infor-app.jpg" alt="MCNexus license, activation, installation, and plugin management workflow" width="100%">

## For Developers

Nexus supports distribution workflows for commercial and open-source OFX
projects. Integrations are currently reviewed and configured per project;
there is no public self-service onboarding process.

- **Licensing backends:** OpenKey is the Nexus-native License Provider, while
  Cryptlex provides hardware-bound commercial licensing. MCNexus validates
  both license types.
- **Current Commerce composition:** GitHub provides verified identity, Stripe
  confirms payment, OpenKey performs license fulfillment, and MailerLite
  delivers operational messages. Full Commerce fulfillment through Cryptlex
  and additional payment and email providers remain on the roadmap.
- **External commercial channels:** products licensed or sold through a
  configured external service can use the same activation, release,
  protected-download, installation, update, and rollback workflow.
- **Release management:** OpenKey projects can use GitHub Releases, while
  Cryptlex-configured products can use releases hosted by that provider. Both
  use platform-specific packages, protected downloads, version discovery,
  updates, and rollback in MCNexus.
[Understand developer integration](docs/DEVELOPERS.md)

## Application Compatibility

- **macOS:** macOS 15 or later, including Apple Silicon and supported Intel Macs.
- **Windows:** Windows 10/11 x64, with Windows 11 ARM support through x64 emulation.
- **Linux:** under consideration when compatible plugins and user demand
  justify the additional platform lifecycle.

## Project

Nexus combines software engineering with practical experience in audiovisual
post-production. Developed independently by
[Magno Ciqueira](https://www.linkedin.com/in/ciqueira/)
([Instagram](https://www.instagram.com/magnociqueira/)), the project aims to
reduce technical friction and provide distribution infrastructure for
commercial and open-source tools.

## Documentation

- [Discovery](docs/DISCOVERY.md)
- [User Guide](docs/USER_GUIDE.md)
- [Developer Documentation](docs/DEVELOPERS.md)
- [Frequently Asked Questions](docs/FAQ.md)
- [Roadmap](docs/ROADMAP.md)
- [License](LICENSE.md)
- [Source Notice](NOTICE.md)
- [Trademark Notice](TRADEMARKS.md)
- [Security Policy](SECURITY.md)
- [Terms of Use](TERMS.md)
- [Privacy Policy](PRIVACY.md)
- [Tenant Legal Documentation Guide](docs/TENANT_LEGAL_GUIDE.md)

## Source Availability

This repository is public for transparency and review. It is source-available, not open source software. Redistribution, unofficial builds, derivative products, and use of MCNexus branding require prior written permission. See [LICENSE.md](LICENSE.md), [NOTICE.md](NOTICE.md), and [TRADEMARKS.md](TRADEMARKS.md).

## Support

Use the [GitHub support forms](https://github.com/ciqueira/MCNexus/issues/new/choose) for technical problems, activation questions, bug reports, and suggestions. Include the operating-system version, MCNexus version, affected plugin, and available diagnostics.

GitHub Issues are public and indexed by search engines. Do not publish a complete license key or personal data. Privacy requests must be sent to [nexus@magnociqueira.com.br](mailto:nexus@magnociqueira.com.br).
