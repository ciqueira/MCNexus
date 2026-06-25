namespace MCAppsTools
{
    public sealed class PersistedReleaseVersionRecord
    {
        public string Version { get; set; } = string.Empty;
        public string Channel { get; set; } = "stable";
        public string ReleaseId { get; set; } = string.Empty;
    }
}
