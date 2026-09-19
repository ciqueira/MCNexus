MCNexus - preview build

Installation
1. Open the DMG file.
2. Drag MCNexus.app to Applications.
3. On first launch, Control-click MCNexus.app and choose Open.
4. Confirm Open again if macOS warns that the app is from an unidentified developer.

Important notes
- This build is not signed with a Developer ID and is not notarized by Apple.
- macOS may block the first launch. First, Control-click MCNexus.app, choose Open, and confirm the launch.
- If the block continues, open System Settings > Privacy & Security and allow MCNexus to run.
- Alternatively, if the app was downloaded from an official and trusted source, run the following command in Terminal:
  xattr -cr /Applications/MCNexus.app
- Then try opening MCNexus again.
- The app may request an administrator password when installing or removing plugins under /Library/OFX/Plugins.

Privacy
- MCNexus processes information required for licensing, product delivery, security, updates, and support.
- Limited technical data may be processed for security, reliability, diagnostics, and service improvement, as described in the Privacy Policy.
- Complete Privacy Policy in Portuguese and English:
  https://github.com/ciqueira/MCNexus/blob/main/PRIVACY.md

When reporting an issue, please include:
- macOS version.
- Mac model and chip (Intel/Apple Silicon).
- Screenshot or exact text of the error message.
- Fingerprint ID shown under Diagnostics inside the app.
