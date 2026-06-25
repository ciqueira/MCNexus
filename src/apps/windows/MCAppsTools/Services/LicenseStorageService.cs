using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace MCAppsTools
{
    public sealed class LicenseStorageService
    {
        private static readonly JsonSerializerOptions JsonOptions = new()
        {
            WriteIndented = true
        };

        static LicenseStorageService()
        {
            JsonOptions.Converters.Add(new JsonStringEnumConverter());
        }

        private readonly AppPaths _paths;
        private readonly SecureDataProtector _protector;

        public LicenseStorageService(string machineFingerprint)
            : this(new AppPaths(), machineFingerprint)
        {
        }

        public LicenseStorageService(AppPaths paths, string machineFingerprint)
        {
            _paths = paths;
            _protector = new SecureDataProtector(machineFingerprint);
        }

        public List<PluginLicenseItem>? Load()
        {
            _paths.EnsureDirectories();
            if (!File.Exists(_paths.LicenseMetadataPath))
            {
                return null;
            }

            var json = File.ReadAllText(_paths.LicenseMetadataPath);
            var records = JsonSerializer.Deserialize<List<PersistedLicenseRecord>>(json, JsonOptions) ?? new List<PersistedLicenseRecord>();
            var licenses = new List<PluginLicenseItem>();

            foreach (var record in records)
            {
                var key = TryLoadProtectedKey(record.Id);
                var productData = TryLoadProtectedProductData(record.ProductId) ?? record.LegacyProductData;
                var previousVersions = record.PreviousVersions
                    .Select(version => new ReleaseVersionInfo(version.Version, version.Channel, version.ReleaseId ?? string.Empty))
                    .ToArray();

                var lifecycleState = record.IsRevoked
                    ? PluginLifecycleState.Deactivating
                    : string.IsNullOrWhiteSpace(key)
                        ? PluginLifecycleState.Deactivating
                        : record.LifecycleState;

                var license = PluginLicenseItem.Create(
                    record.Id == Guid.Empty ? Guid.NewGuid() : record.Id,
                    record.PluginName,
                    record.ProductId ?? string.Empty,
                    record.Edition,
                    lifecycleState,
                    key ?? string.Empty,
                    record.InstalledVersion,
                    record.InstalledReleaseId ?? string.Empty,
                    record.IsRevoked ? null : record.AvailableVersion,
                    record.IsRevoked ? string.Empty : record.AvailableReleaseId ?? string.Empty,
                    record.ActivationDate,
                    record.PluginUpdateDate,
                    record.ActivationUsage,
                    previousVersions,
                    record.InstalledBundleNames,
                    null,
                    record.SkipLocalActivation,
                    productData,
                    record.PurchaseUrl);

                license.DeactivationDate = record.IsRevoked && string.IsNullOrWhiteSpace(record.DeactivationDate)
                    ? DateTime.Now.ToString("dd/MM/yyyy HH:mm:ss", System.Globalization.CultureInfo.InvariantCulture)
                    : record.DeactivationDate;
                license.IsRevoked = record.IsRevoked;
                license.IsCredentialMissing = string.IsNullOrWhiteSpace(key);
                licenses.Add(license);
            }

            return licenses;
        }

        public void Save(IEnumerable<PluginLicenseItem> licenses)
        {
            _paths.EnsureDirectories();
            var licenseList = licenses.ToList();
            var records = new List<PersistedLicenseRecord>();

            foreach (var license in licenseList)
            {
                SaveProtectedKey(license.Id, license.DisplayKey);
                SaveProtectedProductData(license.ProductId, license.ProductData);
                records.Add(new PersistedLicenseRecord
                {
                    Id = license.Id,
                    PluginName = license.PluginName,
                    ProductId = license.ProductId,
                    Edition = license.Edition,
                    LifecycleState = license.LifecycleState,
                    InstalledVersion = license.InstalledVersion,
                    InstalledReleaseId = license.InstalledReleaseId,
                    AvailableVersion = license.AvailableVersion,
                    AvailableReleaseId = license.AvailableReleaseId,
                    ActivationDate = license.ActivationDate,
                    PluginUpdateDate = license.PluginUpdateDate,
                    DeactivationDate = license.DeactivationDate,
                    ActivationUsage = license.ActivationUsage,
                    PurchaseUrl = license.PurchaseUrl,
                    IsRevoked = license.IsRevoked,
                    SkipLocalActivation = license.SkipLocalActivation,
                    InstalledBundleNames = license.InstalledBundleNames.ToList(),
                    PreviousVersions = license.PreviousVersions
                        .Select(version => new PersistedReleaseVersionRecord
                        {
                            Version = version.Version,
                            Channel = version.Channel,
                            ReleaseId = version.ReleaseId
                        })
                        .ToList()
                });
            }

            var json = JsonSerializer.Serialize(records, JsonOptions);
            WriteAtomic(_paths.LicenseMetadataPath, json);
            DeleteStaleProtectedKeyFiles(licenseList.Select(license => license.Id).ToHashSet());
            DeleteStaleProtectedProductFiles(licenseList.Select(license => license.ProductId).Where(id => !string.IsNullOrWhiteSpace(id)).ToHashSet(StringComparer.OrdinalIgnoreCase));
        }

        private string? TryLoadProtectedKey(Guid id)
        {
            var path = KeyPath(id);
            if (!File.Exists(path))
            {
                return null;
            }

            try
            {
                return _protector.UnprotectString(File.ReadAllBytes(path));
            }
            catch
            {
                return null;
            }
        }

        private void SaveProtectedKey(Guid id, string key)
        {
            if (string.IsNullOrWhiteSpace(key) || key == "Key missing")
            {
                return;
            }

            File.WriteAllBytes(KeyPath(id), _protector.ProtectString(key));
        }

        private string? TryLoadProtectedProductData(string productId)
        {
            if (string.IsNullOrWhiteSpace(productId))
            {
                return null;
            }

            var path = ProductDataPath(productId);
            if (!File.Exists(path))
            {
                return null;
            }

            try
            {
                return _protector.UnprotectString(File.ReadAllBytes(path));
            }
            catch
            {
                return null;
            }
        }

        private void SaveProtectedProductData(string productId, string? productData)
        {
            if (string.IsNullOrWhiteSpace(productId))
            {
                return;
            }

            if (string.IsNullOrWhiteSpace(productData))
            {
                DeleteFileIfExists(ProductDataPath(productId));
                return;
            }

            File.WriteAllBytes(ProductDataPath(productId), _protector.ProtectString(productData));
        }

        private void DeleteStaleProtectedKeyFiles(HashSet<Guid> activeIds)
        {
            foreach (var file in Directory.EnumerateFiles(_paths.RecordsDirectory, "*.dat"))
            {
                var fileName = Path.GetFileNameWithoutExtension(file);
                if (Guid.TryParse(fileName, out var id) && !activeIds.Contains(id))
                {
                    DeleteFileIfExists(file);
                }
            }
        }

        private void DeleteStaleProtectedProductFiles(HashSet<string> activeProductIds)
        {
            var activeFileNames = activeProductIds
                .Select(ProductDataFileName)
                .ToHashSet(StringComparer.OrdinalIgnoreCase);

            foreach (var file in Directory.EnumerateFiles(_paths.ProductCredentialsDirectory, "*.bin"))
            {
                if (!activeFileNames.Contains(Path.GetFileName(file)))
                {
                    DeleteFileIfExists(file);
                }
            }
        }

        public bool KeyFileExists(Guid id)
        {
            return File.Exists(KeyPath(id));
        }

        private string KeyPath(Guid id)
        {
            return Path.Combine(_paths.RecordsDirectory, $"{id:N}.dat");
        }

        private string ProductDataPath(string productId)
        {
            return Path.Combine(_paths.ProductCredentialsDirectory, ProductDataFileName(productId));
        }

        private static string ProductDataFileName(string productId)
        {
            var hash = SHA256.HashData(Encoding.UTF8.GetBytes(productId.Trim().ToLowerInvariant()));
            return $"{Convert.ToHexString(hash).ToLowerInvariant()}.bin";
        }

        private static void WriteAtomic(string path, string content)
        {
            var tempPath = $"{path}.tmp";
            File.WriteAllText(tempPath, content);
            File.Move(tempPath, path, true);
        }

        private static void DeleteFileIfExists(string path)
        {
            try
            {
                if (File.Exists(path))
                {
                    File.Delete(path);
                }
            }
            catch
            {
                // Best-effort cleanup. A locked stale secret should not break app startup/save.
            }
        }
    }
}
