namespace MCAppsTools
{
    /// <summary>
    /// License details reported by the local SDK runtime (NexKeyRuntime or Cryptlex).
    /// Mirrors macOS <c>LicenseInfo</c>.
    /// </summary>
    public sealed class SdkLicenseInfo
    {
        public LicenseEdition Edition { get; init; } = LicenseEdition.Full;
        public int ActivationsUsed { get; init; }
        public int MaxActivations { get; init; }
        public string? ActivationUsage { get; init; }
    }
}
