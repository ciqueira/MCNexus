using System;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace MCAppsTools
{
    /// <summary>
    /// Caches the NexKeyRuntime configuration (tenantId/variant/productData)
    /// the BACKEND reported for one product, between launches. Port of
    /// macOS's <c>NexKeyRuntimeConfigurationStore</c>, backed by the
    /// existing <see cref="SecureDataProtector"/> (DPAPI) instead of
    /// reimplementing AES-GCM — Windows already has an OS-level protected
    /// store, macOS did not.
    ///
    /// DELIBERATELY its own directory and its own entropy namespace, not
    /// <see cref="LicenseStorageService"/>'s ProductCredentials store: that
    /// one's mere non-emptiness is load-bearing elsewhere (a Cryptlex
    /// deactivation path reads it as "this license has a local Cryptlex
    /// activation"). Writing a NexKey-shaped blob there — or reusing its
    /// entropy so a stale blob could silently unprotect under either DPAPI
    /// call — would make that check answer yes for a license Cryptlex
    /// cannot deactivate. Two runtimes, two stores, no shared key space.
    /// </summary>
    public sealed class NexKeyRuntimeConfigurationStore
    {
        private const string EntropyNamespace = "MCAppsTools.Windows.NexKeyRuntimeConfigurationStore.v1";

        private readonly AppPaths _paths;
        private readonly SecureDataProtector _protector;

        public NexKeyRuntimeConfigurationStore(string machineFingerprint)
            : this(new AppPaths(), machineFingerprint)
        {
        }

        public NexKeyRuntimeConfigurationStore(AppPaths paths, string machineFingerprint)
        {
            _paths = paths;
            _protector = new SecureDataProtector($"{EntropyNamespace}.{machineFingerprint}");
        }

        public void Save(NexKeyProductDataEntry entry, string productId)
        {
            if (string.IsNullOrWhiteSpace(productId))
            {
                return;
            }

            Directory.CreateDirectory(_paths.NexKeyRuntimeConfigDirectory);
            var json = JsonSerializer.Serialize(entry);
            File.WriteAllBytes(FilePath(productId), _protector.ProtectString(json));
        }

        /// <summary>
        /// Best-effort by contract — every failure returns <c>null</c>
        /// rather than throwing, because the only caller is
        /// <see cref="NexKeyProductDataResolver"/>, whose fallback (the
        /// compiled-in catalog) is the right answer for every one of them.
        /// A decrypt failure is expected and not a bug: the DPAPI entropy
        /// includes the machine fingerprint, so restoring this app's
        /// AppData onto different hardware leaves a file that cannot open —
        /// the next validate-installation rewrites it for the new machine.
        /// </summary>
        public NexKeyProductDataEntry? Load(string productId)
        {
            if (string.IsNullOrWhiteSpace(productId))
            {
                return null;
            }

            try
            {
                var path = FilePath(productId);
                if (!File.Exists(path))
                {
                    return null;
                }

                var json = _protector.UnprotectString(File.ReadAllBytes(path));
                var entry = JsonSerializer.Deserialize<NexKeyProductDataEntry>(json);
                if (entry is null ||
                    string.IsNullOrEmpty(entry.ProductData) ||
                    string.IsNullOrEmpty(entry.TenantId) ||
                    string.IsNullOrEmpty(entry.Variant))
                {
                    return null;
                }

                return entry;
            }
            catch
            {
                return null;
            }
        }

        public void Remove(string productId)
        {
            try
            {
                var path = FilePath(productId);
                if (File.Exists(path))
                {
                    File.Delete(path);
                }
            }
            catch
            {
                // Best-effort cleanup, same discipline as LicenseStorageService.
            }
        }

        private string FilePath(string productId)
        {
            var hash = SHA256.HashData(Encoding.UTF8.GetBytes(productId.Trim().ToLowerInvariant()));
            return Path.Combine(_paths.NexKeyRuntimeConfigDirectory, Convert.ToHexString(hash).ToLowerInvariant() + ".bin");
        }
    }
}
