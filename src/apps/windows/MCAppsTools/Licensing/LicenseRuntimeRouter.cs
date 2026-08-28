using System;

namespace MCAppsTools
{
    /// <summary>
    /// Resolves which <see cref="ILicenseRuntimeProvider"/> a given
    /// license's local SDK calls go through, based on the
    /// <see cref="LicenseRuntime"/> the backend already returned for that
    /// license. Port of macOS's <c>LicenseRuntimeRouter</c>. Deliberately
    /// stateless per call — resolution happens per license, not once for
    /// the whole app, because two different products on the same machine
    /// can legitimately resolve to two different runtimes at the same time.
    /// </summary>
    public sealed class LicenseRuntimeRouter : IDisposable
    {
        private readonly ILicenseRuntimeProvider _cryptlexProvider;
        private readonly ILicenseRuntimeProvider _nexKeyProvider;

        public LicenseRuntimeRouter(ILicenseRuntimeProvider? cryptlexProvider = null, ILicenseRuntimeProvider? nexKeyProvider = null)
        {
            _cryptlexProvider = cryptlexProvider ?? new CryptlexRuntimeProvider();
            _nexKeyProvider = nexKeyProvider ?? new NexKeyRuntimeProvider();
        }

        /// <summary>
        /// <c>null</c> runtime is what every <see cref="PersistedLicenseRecord"/>
        /// written before this field existed decodes to — resolving it to
        /// Cryptlex is what makes that decode a no-op for every record
        /// already on disk. <see cref="LicenseRuntime.LegacyBackendOnly"/>
        /// resolves to <c>null</c>: no local SDK activation for that
        /// runtime, by design (D41) — the caller treats a <c>null</c>
        /// provider exactly like today's <c>SkipLocalActivation</c> path.
        /// </summary>
        public ILicenseRuntimeProvider? Provider(LicenseRuntime? runtime)
        {
            return runtime switch
            {
                null or LicenseRuntime.CryptlexLexActivatorV1 or LicenseRuntime.Unknown => _cryptlexProvider,
                LicenseRuntime.NexkeyRuntimeV1 => _nexKeyProvider,
                LicenseRuntime.LegacyBackendOnly => null,
                _ => _cryptlexProvider
            };
        }

        /// <summary>
        /// Releases native resources held by either provider —
        /// <see cref="NexKeyRuntimeProvider"/>'s handles, in practice;
        /// <see cref="CryptlexRuntimeProvider"/> owns nothing disposable.
        /// </summary>
        public void Dispose()
        {
            (_cryptlexProvider as IDisposable)?.Dispose();
            (_nexKeyProvider as IDisposable)?.Dispose();
        }
    }
}
