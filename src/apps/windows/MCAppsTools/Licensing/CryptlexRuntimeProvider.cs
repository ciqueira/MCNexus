using System.Threading.Tasks;

namespace MCAppsTools
{
    /// <summary>
    /// Adapts the existing <see cref="LexService"/> to
    /// <see cref="ILicenseRuntimeProvider"/> — the sibling of
    /// <see cref="NexKeyRuntimeProvider"/> behind
    /// <see cref="LicenseRuntimeRouter"/> (D12: the two runtimes coexist).
    /// Deliberately a thin wrapper: every call forwards straight to
    /// <see cref="LexService"/> with no behavior change, so routing a
    /// Cryptlex-runtime license through here is a no-op compared to today's
    /// direct calls.
    /// </summary>
    public sealed class CryptlexRuntimeProvider : ILicenseRuntimeProvider
    {
        private readonly LexService _lexService;

        public CryptlexRuntimeProvider(LexService? lexService = null)
        {
            _lexService = lexService ?? new LexService();
        }

        public Task<bool> ActivateAsync(string productId, string licenseKey, string? productData, string machineFingerprint)
        {
            return _lexService.ActivateAsync(productId, licenseKey, productData, machineFingerprint);
        }

        public Task DeactivateAsync(string productId, string? productData)
        {
            _lexService.Deactivate(productId, productData);
            return Task.CompletedTask;
        }

        public Task<SdkLicenseStatus> ValidateAsync(string productId, string? productData)
        {
            return Task.FromResult(_lexService.CachedStatus(productId, productData));
        }

        public Task<SdkLicenseStatus> SyncActivationAsync(string productId, string? productData)
        {
            return Task.FromResult(_lexService.SyncStatus(productId, productData));
        }

        public Task<string?> ActivatedKeyAsync(string productId)
        {
            // Cryptlex answers the identity question directly via its own
            // GetLicenseKey; nothing in this app's LexService wrapper reads
            // it today (the view model tracks the key itself), so this stays
            // unimplemented rather than adding a call path nothing needs yet.
            return Task.FromResult<string?>(null);
        }

        public string MachineFingerprint()
        {
            return MachineFingerprintService.Generate();
        }
    }
}
