# User Guide

[English](USER_GUIDE.md) · [Português](../pt-BR/docs/USER_GUIDE.md)

[Home](../README.md) · [Discovery](DISCOVERY.md) · [Developers](DEVELOPERS.md) · [FAQ](FAQ.md) · [Roadmap](ROADMAP.md)

MCNexus centralizes OFX plugin installation, licensing, and version management. This guide covers the normal operating flow and the information required to request support safely.

## 1. Requirements

- **macOS:** macOS 15 or later on Apple Silicon or a supported Intel Mac.
- **Windows:** Windows 10 or 11 x64. Windows 11 ARM uses x64 emulation.
- **Internet connection:** required to check licenses, versions, and downloads.
- **System permissions:** installing OFX files may require authorization to write to the shared plugin directory.

Close OFX host applications before installing, updating, rolling back, or removing a plugin. This reduces the chance of files remaining locked during the operation.

## 2. Installing MCNexus

Use the official links in the [MCNexus repository](../README.md). On Windows, installation through the <a href="https://apps.microsoft.com/detail/9n1qqt1xc825" target="_blank" rel="noopener noreferrer">Microsoft Store</a> is recommended. A direct `.exe` installer is also available through GitHub. On macOS, download the official `.dmg` from GitHub.

The direct Windows installer may display a Microsoft Defender SmartScreen warning because it is not currently code-signed. The macOS build may display a Gatekeeper warning because signing and notarization work is still in progress. Do not use installers supplied by third parties.

On Windows, some operations may request administrator privileges. On macOS, the system may request equivalent authorization.

## 3. Obtaining and entering a key

OpenKey licenses are obtained exclusively through the **Get Key** link provided for each plugin in [Discovery](DISCOVERY.md) or through its official channel. The link requests GitHub authentication and requires an account with a verified primary email. The key is then displayed for use in MCNexus. Opening the same link again with the same account returns the previously generated key.

Commercial plugins provide credentials through the purchase and delivery process defined by the developer.

After receiving a key:

1. Open MCNexus.
2. Enter the key through the plugin addition or activation flow.
3. Check the displayed product and status before starting installation.
4. Never share or publish the complete key.

## 4. Installing plugins

MCNexus downloads the artifact for the operating system and installs files in the native OFX directory:

- **Windows:** normally `C:\Program Files\Common Files\OFX\Plugins`;
- **macOS:** normally `/Library/OFX/Plugins`.

After installation, reopen the editing or color-grading application so it can scan for plugins again. If the plugin does not appear, restart the host application before repeating the installation.

## 5. License states

The state shown by MCNexus helps identify the next action:

- **Active:** the license is valid for the current machine.
- **Not active:** the key is known but has not been activated on this machine.
- **Suspended:** use was suspended by the licensing service and requires review.
- **Unavailable:** no activation is available or the license cannot currently be used.
- **Corrupted or local problem:** locally stored data could not be validated.

Exact wording may vary between versions. When requesting support, include the displayed state and use the copy-diagnostics function when available.

## 6. License and plugin actions

These actions have different effects:

- **Activate license:** binds the license to the current machine within its activation limit.
- **Deactivate license:** ends the activation associated with the current machine when the operation is available.
- **Remove key:** deletes the locally stored credential. This alone does not mean that the remote activation was released.
- **Remove plugin:** deletes installed OFX files. This does not necessarily remove the key or deactivate the license.

Before formatting, selling, or retiring a machine, deactivate any licenses that you intend to reuse.

## 7. Moving to another computer

When the previous computer is still accessible:

1. Open MCNexus on the previous machine.
2. Deactivate the license.
3. Install MCNexus on the new machine.
4. Enter the key and activate it.
5. Install the plugin.

When the previous machine is unavailable because of loss, hardware failure, or reformatting, open the [activation problem form](https://github.com/ciqueira/MCNexus/issues/new?template=activation_problem.yml). If a key reference is required, provide only its final four characters.

Fully self-service remote activation management remains on the [Roadmap](ROADMAP.md).

## 8. Updates

MCNexus checks published versions and displays a notification when it finds a compatible update.

Before updating a plugin used in active work:

1. confirm that the project is saved and backed up;
2. close the host application;
3. check the version that will be installed;
4. run the update;
5. reopen the application and validate the plugin in the project.

## 9. Previous versions and rollback

When previous releases are available in the history, select the required version in MCNexus. The application replaces the installed files with the chosen artifact.

Rollback changes the plugin binary, but it does not modify projects or guarantee that settings created with newer versions are compatible with older versions. Back up important work before changing versions.

## 10. Recovering from failures

Failed installation, update, or rollback operations may provide retry or cancel actions. Before retrying:

- close applications that may be using the plugin;
- confirm the internet connection;
- check available disk space;
- confirm that requested system permissions were granted;
- avoid running two operations on the same plugin simultaneously.

If the failure continues, copy diagnostics before closing MCNexus.

## 11. Removal and uninstallation

Removing a plugin through MCNexus deletes OFX files managed by the application. License deactivation and local key removal are separate actions.

When uninstalling MCNexus on Windows, the installer may offer choices concerning local data. OFX plugins may remain installed depending on those choices. If you intend to reuse a license on another computer, deactivate it before removing the application.

## 12. Support

> **Important:** Nexus provides support for installation, activation, updates, and removal. Problems with how a plugin functions should be reported to its developer. If you are unsure, we can help identify the correct support channel.

Use the appropriate [GitHub Issues form](https://github.com/ciqueira/MCNexus/issues/new/choose) for:

- MCNexus installation, update, launch, or removal problems;
- plugin installation, update, rollback, or removal problems;
- license activation or availability problems;
- general support.

Before opening a request, collect:

- operating system and version;
- MCNexus version;
- plugin name and version;
- action performed;
- expected result and observed behavior;
- displayed message;
- diagnostics copied by the application when available.

GitHub Issues are public and indexed by search engines. Remove names, email addresses, user paths, and other personal data from diagnostics. Do not publish a complete license key.

Requests to access, correct, or delete personal data must be sent privately to [nexus@magnociqueira.com.br](mailto:nexus@magnociqueira.com.br).
