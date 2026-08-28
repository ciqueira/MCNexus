using System.Threading.Tasks;

namespace MCAppsTools
{
    /// <summary>
    /// One local SDK a license's activation can be routed through — Cryptlex
    /// or NexKeyRuntime. Port of the macOS <c>LicenseProvider</c> protocol
    /// (Fase 5, D41): the app never decides which runtime a license uses,
    /// the backend does, per request — this interface is what lets
    /// <see cref="LicenseRuntimeRouter"/> hand either implementation to the
    /// view model without it knowing which SDK is underneath.
    /// </summary>
    public interface ILicenseRuntimeProvider
    {
        /// <summary>
        /// Activates <paramref name="licenseKey"/> for <paramref name="productId"/>
        /// on this machine. Mirrors <c>LexService.ActivateAsync</c>'s
        /// existing contract exactly: returns <c>true</c> on success
        /// (including "already active on this machine"), throws
        /// <see cref="System.InvalidOperationException"/> with a
        /// user-facing message on failure. Kept as the contract — rather
        /// than a new result enum — so <c>CryptlexRuntimeProvider</c> can
        /// wrap the existing <see cref="LexService"/> without changing its
        /// behavior, and so the view model's existing catch/error-message
        /// flow at the activation step needs no changes either.
        /// </summary>
        Task<bool> ActivateAsync(string productId, string licenseKey, string? productData, string machineFingerprint);

        /// <summary>Deactivates the current license for <paramref name="productId"/> on this machine.</summary>
        Task DeactivateAsync(string productId, string? productData);

        /// <summary>Local-only check (no network) of whether the license is still genuine.</summary>
        Task<SdkLicenseStatus> ValidateAsync(string productId, string? productData);

        /// <summary>Forces a network round trip to sync activation data from the backend.</summary>
        Task<SdkLicenseStatus> SyncActivationAsync(string productId, string? productData);

        /// <summary>
        /// The license key this provider's local SDK state currently
        /// belongs to, or <c>null</c> when it cannot tell (no cached
        /// identity, or the state is about a different key). Strictly an
        /// identity question, never a health question — callers that want
        /// health call <see cref="ValidateAsync"/>/<see cref="SyncActivationAsync"/>.
        /// </summary>
        Task<string?> ActivatedKeyAsync(string productId);

        /// <summary>
        /// This provider's own identifier for the local activation, if it
        /// has one. Cryptlex has no equivalent concept (its key IS the
        /// identity) and returns <c>null</c>; NexKeyRuntime uses this to
        /// survive a relaunch, since its ABI never hands the raw key back.
        /// </summary>
        Task<string?> LocalActivationIdentifierAsync(string productId)
        {
            return Task.FromResult<string?>(null);
        }

        /// <summary>
        /// Re-establishes, after a relaunch, that this provider's local
        /// state belongs to <paramref name="licenseKey"/>. Deliberately
        /// pessimistic by default (<c>false</c>) — a provider with no local
        /// activation identifier of its own has no safe way to confirm this,
        /// and defaulting to "adopted" would let one license's local state
        /// be reported as another's after the machine holds a seat for a
        /// DIFFERENT license under the same product (deactivate A, activate
        /// B).
        /// </summary>
        Task<bool> AdoptLocalActivationAsync(string productId, string licenseKey, string? activationId)
        {
            return Task.FromResult(false);
        }

        /// <summary>The machine identifier this provider's SDK uses for activation.</summary>
        string MachineFingerprint();
    }
}
