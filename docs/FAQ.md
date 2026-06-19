# Frequently Asked Questions

[English](FAQ.md) · [Português](../pt-BR/docs/FAQ.md)

[Home](../README.md) · [Discovery](DISCOVERY.md) · [User Guide](USER_GUIDE.md) · [Developers](DEVELOPERS.md) · [Roadmap](ROADMAP.md)

## How does MCNexus install plugins?

The installed version of MCNexus places OFX files in the native directory used by editing and color-grading applications.

## Can I move a license to another computer?

Commercial licenses use hardware-bound activation. If the previous computer is accessible, deactivate the license there before activating it on the new computer. Removing the local key or plugin files alone should not be treated as releasing the activation.

If the previous computer was lost, reformatted, or is no longer accessible, use the [activation problem form](https://github.com/ciqueira/MCNexus/issues/new?template=activation_problem.yml) to request an activation review. Never publish the complete key.

## Can I use the same license on two workstations at once?

This depends on the activation limit assigned to the purchased license. MCNexus does not automatically increase that limit. If all activations are occupied, deactivate an accessible installation or request support.

## How do update notifications work?

MCNexus checks available releases and displays a notification when it finds a compatible update. Installation requires user confirmation.

## How does rollback work?

Open the plugin release history in MCNexus and select the required version. The application replaces the plugin files automatically.

## How do I get technical support?

Choose the appropriate form in the [Support Center](https://github.com/ciqueira/MCNexus/issues/new/choose). Separate forms are available for application installation, plugin installation, license activation, and general support.

> **Important:** MCNexus provides support for installation, activation, updates, and removal. Problems with how a plugin functions should be reported to its developer. If you are unsure, we can help identify the correct support channel.

GitHub Issues are public and indexed by search engines. Do not publish personal data or a complete license key.

## What is the difference between Commercial and OpenKey distribution?

Commercial distribution uses Cryptlex for hardware-bound license validation. OpenKey supports the distribution of open-source projects without a third-party commercial licensing dependency.

## How do I obtain an OpenKey license?

Use the plugin's **Get Key** link in [Discovery](DISCOVERY.md) or through its official channel. This is the only way to issue an OpenKey license and requires authentication with a GitHub account that has a verified primary email. If a license has already been generated for that account, the same link displays the existing key again.

## How are purchases and licenses connected?

Stripe or an integrated checkout partner processes the transaction. License generation and credential delivery through MailerLite are automated after confirmation.

## Which release channels are supported?

OpenKey can use Beta, Demo, and Full channels. Commercial distribution uses Demo and Full editions only.

## What is the difference between deactivating a license, removing a key, and removing a plugin?

- **Deactivate license:** ends the activation associated with that machine when the operation is available.
- **Remove key:** deletes the locally stored credential without necessarily removing plugin files.
- **Remove plugin:** deletes installed OFX files without necessarily releasing the remote activation.

Read the [User Guide](USER_GUIDE.md) before changing computers or reinstalling the operating system.

## Does MCNexus comply with data-protection laws?

MCNexus processes only the data required for licensing, product delivery, security, and support. See the [Privacy Policy](../PRIVACY.md) for complete information.

## How can I make a personal-data request?

Send the request to [nexus@magnociqueira.com.br](mailto:nexus@magnociqueira.com.br). Privacy requests must not be posted through GitHub Issues.
