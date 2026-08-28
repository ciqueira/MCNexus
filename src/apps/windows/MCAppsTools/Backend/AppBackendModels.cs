using System.Collections.Generic;
using System.Text.Json.Serialization;

namespace MCAppsTools
{
    public sealed class AppBackendProductDto
    {
        public string Name { get; set; } = string.Empty;

        [JsonPropertyName("productID")]
        public string ProductId { get; set; } = string.Empty;

        [JsonPropertyName("purchaseURL")]
        public string? PurchaseUrl { get; set; }

        public string? ProductData { get; set; }
    }

    public sealed class AppBackendReleaseDto
    {
        public string Id { get; set; } = string.Empty;
        public string Name { get; set; } = string.Empty;
        public string Version { get; set; } = string.Empty;
        public string Platform { get; set; } = string.Empty;
        public string? Channel { get; set; }
        public string? UpdatedAt { get; set; }
        public string? PublishedAt { get; set; }
        public int? TotalFiles { get; set; }
    }

    public sealed class AppBackendMessageDto
    {
        public string Code { get; set; } = string.Empty;
        public string Message { get; set; } = string.Empty;
    }

    public sealed class AppBackendErrorDto
    {
        public string Code { get; set; } = string.Empty;
        public string Message { get; set; } = string.Empty;
    }

    public sealed class HealthResponseDto
    {
        public string Status { get; set; } = string.Empty;
        public string? Version { get; set; }
    }

    public sealed class ValidateInstallationRequestDto
    {
        public string Key { get; set; } = string.Empty;
        public string MachineFingerprint { get; set; } = string.Empty;
        public bool ActivateOnMachine { get; set; } = true;
    }

    public sealed class ValidateInstallationResponseDto
    {
        public AppBackendProductDto Product { get; set; } = new();
        public string Edition { get; set; } = string.Empty;
        public bool? SkipLocalActivation { get; set; }
        public string ActivationUsage { get; set; } = string.Empty;
        public List<AppBackendReleaseDto> Releases { get; set; } = new();
        public string? SessionToken { get; set; }
        public int? ExpiresIn { get; set; }
        public AppBackendMessageDto? Message { get; set; }

        // Fase 5 (D41) — additive. Absent on an older backend or a tenant
        // not yet on the SDK; LicenseRuntimeWire.FromWireValue treats a
        // missing/empty Licensing the same way: Cryptlex, today's only
        // runtime. Without TenantId the SDK bridge cannot call
        // set_tenant_id, so load_local would fail with INVALID_CONFIG.
        public string? TenantId { get; set; }
        public LicensingDto? Licensing { get; set; }

        // Whether THIS machine still holds a seat, distinct from the
        // license's own status — see MachineActivationState-equivalent
        // handling at the call site. "unknown" (server could not derive
        // this machine's SDK identity — true for every Windows client
        // today, since MCNexus reads the WMI SMBIOS UUID and the SDK reads
        // MachineGuid) must never be read as "removed".
        public string? Activation { get; set; }

        // Always exactly one for an OpenKey license (the backend enforces
        // that) — it is what the SDK calls the "variant". Optional: an
        // older backend omits it and NexKeyRuntimeProvider falls back to
        // the default entitlement.
        public List<string>? Entitlements { get; set; }
    }

    public sealed class SyncLicenseRequestDto
    {
        public string MachineFingerprint { get; set; } = string.Empty;
    }

    public sealed class SyncLicenseResponseDto
    {
        public AppBackendProductDto Product { get; set; } = new();
        public string? Edition { get; set; }
        public string Status { get; set; } = string.Empty;
        public string ActivationUsage { get; set; } = string.Empty;
        public List<AppBackendReleaseDto> Releases { get; set; } = new();
        public string? SessionToken { get; set; }
        public int? ExpiresIn { get; set; }
        public string? TenantId { get; set; }
        public LicensingDto? Licensing { get; set; }
        public string? Activation { get; set; }
    }

    public sealed class SyncBatchRequestDto
    {
        public string MachineFingerprint { get; set; } = string.Empty;
        public List<SyncBatchItemDto> Items { get; set; } = new();
    }

    public sealed class SyncBatchItemDto
    {
        public string Key { get; set; } = string.Empty;
        public string? SessionToken { get; set; }
    }

    public sealed class SyncBatchResponseDto
    {
        public List<SyncBatchResultDto> Results { get; set; } = new();
    }

    public sealed class SyncBatchResultDto
    {
        public string Key { get; set; } = string.Empty;
        public bool Ok { get; set; }
        public string? Status { get; set; }
        public string? Edition { get; set; }
        public bool? SkipLocalActivation { get; set; }
        public string? ActivationUsage { get; set; }
        public AppBackendProductDto? Product { get; set; }
        public List<AppBackendReleaseDto>? Releases { get; set; }
        public string? SessionToken { get; set; }
        public int? ExpiresIn { get; set; }
        public AppBackendMessageDto? Message { get; set; }
        public AppBackendErrorDto? Error { get; set; }
        public string? TenantId { get; set; }
        public LicensingDto? Licensing { get; set; }
        public string? Activation { get; set; }
        public List<string>? Entitlements { get; set; }
    }

    public sealed class MigrateBindingRequestDto
    {
        // Only meaningful on Windows: the app reads the WMI SMBIOS UUID
        // while the SDK reads MachineGuid, and the server cannot derive one
        // from the other (unlike macOS, where both read IOPlatformUUID and
        // the field may be omitted). Backend route already accepts this —
        // routes/licenses.ts:194-201 — MCNexus just never sent it.
        public string HardwareId { get; set; } = string.Empty;
    }

    public sealed class MigrateBindingResponseDto
    {
        public string Outcome { get; set; } = string.Empty;
        public string? ActivationId { get; set; }
    }

    public sealed class ResolveDownloadRequestDto
    {
        public string Platform { get; set; } = "windows";
        public string MachineFingerprint { get; set; } = string.Empty;
    }

    public sealed class ResolveDownloadResponseDto
    {
        public string Name { get; set; } = string.Empty;
        public string Url { get; set; } = string.Empty;
        public string? ExpiresAt { get; set; }
        public int? FileSize { get; set; }
    }

    /// <summary>
    /// Wire shape of the backend's <c>licensing</c> field — a nested object
    /// (<c>{ runtime, generation }</c>, `appClient/src/providers/openkey.ts:515`
    /// and `services/license/validation.ts:273`), NOT a flat string. Declaring
    /// it as <c>string?</c> was the bug behind "the license service returned
    /// an unexpected response": System.Text.Json throws trying to deserialize
    /// a JSON object into a string, on every validate-installation/sync-batch
    /// response, for every tenant — the 200 OK server-side and the client-side
    /// decode failure were never in conflict.
    /// </summary>
    public sealed class LicensingDto
    {
        public string? Runtime { get; set; }
        public int? Generation { get; set; }
    }

    /// <summary>
    /// Wire shape of the backend's <c>/v1/app/latest</c> response
    /// (<c>appClient/src/routes/system.ts:43</c>: <c>{ version, downloadURL }</c>).
    /// Used to carry a SECOND property, <c>DownloadUrlAlias</c>, aliased to
    /// <c>[JsonPropertyName("downloadUrl")]</c> to also accept a lowercase
    /// spelling. That is what silently broke the update-check feature
    /// entirely: <c>JsonSerializerDefaults.Web</c> already sets
    /// <c>PropertyNameCaseInsensitive = true</c>, so "downloadURL" and
    /// "downloadUrl" were the SAME name to System.Text.Json's eyes — two C#
    /// properties mapped to one case-insensitive JSON name is a
    /// <see cref="System.InvalidOperationException"/> at JsonTypeInfo build
    /// time (not a <see cref="System.Text.Json.JsonException"/>, so the
    /// decode-error catch in AppBackendService never saw it), thrown on
    /// every single call and swallowed only by CheckForAppUpdatesAsync's
    /// outer catch-all — no crash, no banner, ever. The single property
    /// below already matches any casing on its own; the alias was never
    /// needed even before this broke.
    /// </summary>
    public sealed class AppLatestResponseDto
    {
        public string Version { get; set; } = string.Empty;

        [JsonPropertyName("downloadURL")]
        public string? DownloadUrl { get; set; }
    }
}
