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

    public sealed class AppLatestResponseDto
    {
        public string Version { get; set; } = string.Empty;

        [JsonPropertyName("downloadURL")]
        public string? DownloadUrl { get; set; }

        [JsonPropertyName("downloadUrl")]
        public string? DownloadUrlAlias
        {
            get => DownloadUrl;
            set
            {
                if (string.IsNullOrWhiteSpace(DownloadUrl))
                {
                    DownloadUrl = value;
                }
            }
        }
    }
}
