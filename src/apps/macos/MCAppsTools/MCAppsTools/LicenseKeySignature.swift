import Foundation

extension String {
    /// Removes the 2-character hex signature suffix added by the backend for
    /// product routing, returning the original Cryptlex key suitable for the
    /// LexActivator SDK. If the string is too short to carry a signature,
    /// returns self unchanged.
    ///
    /// Signed format: `[CRYPTLEX_KEY][2-hex-signature]`
    /// Example: `B5DE40-8610B8-47E695-578E2D-37A3D7-1189D87A` → `B5DE40-8610B8-47E695-578E2D-37A3D7-1189D8`
    nonisolated var unsigned: String {
        guard count > 2 else { return self }
        return String(dropLast(2))
    }

    /// Validates the signed license key format used by MCBackend:
    /// five 6-character hex groups followed by a single 8-character hex group
    /// (the last 2 chars are the routing signature appended by the backend on
    /// top of the original 36-char Cryptlex key).
    ///
    /// Example accepted: `735A2D-B5698A-43A284-BD8EA6-D5F477-72CF13E8`
    nonisolated var isValidSignedLicenseKey: Bool {
        let pattern = #"^[0-9A-Fa-f]{6}-[0-9A-Fa-f]{6}-[0-9A-Fa-f]{6}-[0-9A-Fa-f]{6}-[0-9A-Fa-f]{6}-[0-9A-Fa-f]{8}$"#
        return range(of: pattern, options: .regularExpression) != nil
    }
}
