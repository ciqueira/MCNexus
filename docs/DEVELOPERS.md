# Developer Documentation

[English](DEVELOPERS.md) · [Português](../pt-BR/docs/DEVELOPERS.md)

[Home](../README.md) · [Discovery](DISCOVERY.md) · [User Guide](USER_GUIDE.md) · [FAQ](FAQ.md) · [Roadmap](ROADMAP.md) · [Reviews](REVIEWS.md)

MCNexus provides infrastructure to host, license, and distribute OFX plugins without requiring each developer to build a complete delivery and validation system.

## Distribution Models

### Commercial

Commercial plugins use Cryptlex for cryptographic license-key validation and hardware-bound activation. Stripe and integrated checkout partners can trigger customer registration, license provisioning, and transactional credential delivery.

Demo and Full editions are supported.

### OpenKey

OpenKey supports the distribution of open-source projects without a third-party commercial licensing dependency. Releases are delivered through GitHub.

Hybrid distribution can combine an open-source project with a commercial tier integrated with Stripe.

## Release Channels

Plugins can be organized into controlled Beta, Demo, and Full channels.

## Release Management

MCNexus supports:

- GitHub Releases synchronization;
- platform-specific macOS and Windows artifacts;
- protected download proxying;
- update notifications;
- previous-version installation and rollback.

## Automated Transaction Flow

1. A purchase is completed through Stripe or an integrated checkout partner.
2. The transaction is validated and the license is generated.
3. Credentials and access instructions are delivered through MailerLite or Mailchimp.
4. The user enters the key in MCNexus and the plugin is installed automatically.

Open distribution can use a direct access link instead of a commercial purchase.

## Native Integrations

- **Payments:** Stripe and checkout partners.
- **Licensing:** Cryptlex and OpenKey.
- **Transactional email:** MailerLite and Mailchimp.
- **Releases:** GitHub Releases.

## Integrated Plugins

See [Discovery](DISCOVERY.md) for the plugins currently integrated with MCNexus.
