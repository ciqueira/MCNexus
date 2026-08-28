using System;
using System.Collections.Generic;
using System.Text.Json.Serialization;

namespace MCAppsTools
{
    public sealed class PersistedLicenseRecord
    {
        public Guid Id { get; set; }
        public string PluginName { get; set; } = string.Empty;
        public string ProductId { get; set; } = string.Empty;
        public LicenseEdition Edition { get; set; }
        public PluginLifecycleState LifecycleState { get; set; }
        public string? InstalledVersion { get; set; }
        public string? InstalledReleaseId { get; set; }
        public string? AvailableVersion { get; set; }
        public string? AvailableReleaseId { get; set; }
        public string ActivationDate { get; set; } = string.Empty;
        public string PluginUpdateDate { get; set; } = string.Empty;
        public string? DeactivationDate { get; set; }
        public string ActivationUsage { get; set; } = string.Empty;
        public string? PurchaseUrl { get; set; }
        public bool IsRevoked { get; set; }
        public bool SkipLocalActivation { get; set; }
        [JsonPropertyName("ProductData")]
        [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
        public string? LegacyProductData { get; set; }
        public List<string> InstalledBundleNames { get; set; } = new();
        public List<PersistedReleaseVersionRecord> PreviousVersions { get; set; } = new();

        // Schema 2 (Fase 5, D41/D42) — additive. A record written before
        // these fields existed deserializes with Runtime/TenantId/ActivationId
        // all null, which LicenseRuntimeRouter.Provider(null) resolves to
        // Cryptlex — the same runtime that record has always used, so the
        // decode is a no-op for every file already on disk.
        public LicenseRuntime? Runtime { get; set; }
        public string? TenantId { get; set; }
        public string? ActivationId { get; set; }
    }
}
