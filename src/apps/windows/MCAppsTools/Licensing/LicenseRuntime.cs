namespace MCAppsTools
{
    /// <summary>
    /// Which SDK a license is routed to (Fase 5, D41 — the app never infers
    /// this locally; the backend is the single source of truth per
    /// request). Port of macOS's <c>LicenseRuntime</c>
    /// (<c>LicenseBackendProvider.swift</c>). <see cref="Unknown"/> keeps a
    /// raw string this build has never heard of instead of silently
    /// misreporting it as one of the known cases.
    /// </summary>
    public enum LicenseRuntime
    {
        LegacyBackendOnly,
        CryptlexLexActivatorV1,
        NexkeyRuntimeV1,
        Unknown
    }

    public static class LicenseRuntimeWire
    {
        /// <summary>
        /// Parses the backend's <c>licensing.runtime</c> field.
        /// <c>null</c>/empty — the field omitted, which is every response
        /// from a tenant not yet on the SDK, or from an older backend —
        /// maps to <see cref="LicenseRuntime.CryptlexLexActivatorV1"/>, the
        /// only runtime that has ever existed for this app. Same idiom as
        /// <c>MainWindowViewModel.EditionFromBackend</c>: the wire string
        /// lives in the DTO, the domain enum is derived at the point of
        /// consumption.
        /// </summary>
        public static LicenseRuntime FromWireValue(string? wireValue)
        {
            if (string.IsNullOrWhiteSpace(wireValue))
            {
                return LicenseRuntime.CryptlexLexActivatorV1;
            }

            return wireValue switch
            {
                "openkey_legacy_backend_only" => LicenseRuntime.LegacyBackendOnly,
                "cryptlex_lexactivator_v1" => LicenseRuntime.CryptlexLexActivatorV1,
                "openkey_nexkeyruntime_v1" => LicenseRuntime.NexkeyRuntimeV1,
                _ => LicenseRuntime.Unknown
            };
        }
    }
}
