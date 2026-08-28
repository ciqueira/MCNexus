namespace MCAppsTools
{
    public enum SdkLicenseStatus
    {
        Active,
        Suspended,
        Revoked,
        Expired,
        NotActivated,
        Unknown,

        /// <summary>
        /// NexKeyRuntime only: genuine, but the SDK is inside its offline
        /// grace window (no successful sync recently). Treated as healthy —
        /// Cryptlex/<see cref="LexService"/> has no equivalent state and
        /// never produces this value.
        /// </summary>
        GenuineGracePeriod,

        /// <summary>
        /// NexKeyRuntime only: the license itself is fine, but THIS
        /// machine's seat was released elsewhere (backOffice, another
        /// device, an offline proof). Deliberately distinct from
        /// <see cref="Revoked"/> — reporting revocation here would steer the
        /// UI into a terminal state that offers no way back, when the user
        /// can simply activate again.
        /// </summary>
        DeactivatedRemotely
    }
}
