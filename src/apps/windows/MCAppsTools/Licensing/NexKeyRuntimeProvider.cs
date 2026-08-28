using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

namespace MCAppsTools
{
    /// <summary>
    /// <see cref="ILicenseRuntimeProvider"/> over the NexKeyRuntime C ABI —
    /// the SDK-routed sibling of <see cref="CryptlexRuntimeProvider"/>.
    /// Port of macOS's <c>NexKeyRuntimeProvider.swift</c>; see that file's
    /// comments for the reasoning behind each piece of the status mapping,
    /// most of which came from real bugs (see PLANO_CONSOLIDADO.md, Fase 5).
    ///
    /// Unlike Cryptlex's global mutable state, NexKeyRuntime hands out an
    /// explicit handle per product configuration, created once and reused —
    /// mirroring <c>mc::License</c> in the ColorEqualizer plugin's
    /// <c>MCLicense.h</c>.
    /// </summary>
    public sealed class NexKeyRuntimeProvider : ILicenseRuntimeProvider, IDisposable
    {
        private readonly SemaphoreSlim _gate = new(1, 1);
        private readonly INexKeyProductDataResolver _productDataResolver;
        private readonly Dictionary<string, NexKeyHandleContext> _handles = new(StringComparer.Ordinal);
        private bool _disposed;

        public NexKeyRuntimeProvider(INexKeyProductDataResolver? productDataResolver = null)
        {
            _productDataResolver = productDataResolver
                ?? new NexKeyProductDataResolver(new NexKeyRuntimeConfigurationStore(MachineGuidReader.Generate()));
        }

        private sealed class NexKeyHandleContext
        {
            public required IntPtr Handle { get; init; }
            public required NexKeyProductDataEntry Entry { get; init; }

            // Kept alive here for the handle's whole lifetime — the ABI
            // invokes this on its own poller thread at any time, so letting
            // the GC collect it while nexkeyruntime.dll still holds the
            // pointer would crash the process on the next callback.
            public required NexKeyRuntimeLicenseCallback Callback { get; init; }

            // The key most recently handed to Activate() on this handle,
            // cleared on Deactivate(). The ABI never hands a raw key back
            // (unlike Cryptlex's GetLicenseKey), so this in-memory cache is
            // the only way ActivatedKeyAsync can answer. Does not survive a
            // relaunch — a genuinely active license reads as "unknown key"
            // for one refresh cycle after restart.
            public string? LastActivatedKey;

            // Bumped by the callback (runs on the SDK's poller thread, never
            // on _gate) so SyncActivationAsync can tell a fresh sync result
            // apart from a stale one without racing the callback itself.
            private int _syncSignal;
            public void BumpSyncSignal() => Interlocked.Increment(ref _syncSignal);
            public int SnapshotSyncSignal() => Volatile.Read(ref _syncSignal);
        }

        public void Dispose()
        {
            if (_disposed)
            {
                return;
            }

            _disposed = true;
            _gate.Wait();
            try
            {
                foreach (var context in _handles.Values)
                {
                    NexKeyRuntimeNative.nexkeyruntime_license_destroy(context.Handle);
                }
                _handles.Clear();
            }
            finally
            {
                _gate.Release();
            }
        }

        // MARK: - Handle lifecycle

        /// <summary>
        /// Creates (on first use) and configures the handle for this
        /// product. Must run inside <see cref="RunOnQueueAsync{T}"/>. Order
        /// mirrors <c>mc::License::start()</c> exactly: create -&gt;
        /// set_callback -&gt; set_product_data -&gt; set_tenant_id -&gt;
        /// set_variant -&gt; set_metadata("product", ...) (D40) -&gt;
        /// set_metadata("appVersion", ...) — all before any call that can
        /// consume a seat.
        /// </summary>
        private NexKeyHandleContext? Context(string productId)
        {
            var entry = _productDataResolver.Entry(productId);
            if (entry is null)
            {
                return null;
            }

            if (_handles.TryGetValue(productId, out var existing))
            {
                if (existing.Entry == entry)
                {
                    return existing;
                }

                // The tenant's signing key rotated under a live handle.
                // Rebuilt, not reconfigured: set_product_data is only
                // honoured before the handle's first activate(). Nothing on
                // disk is touched — the receipt and the seat outlive the
                // handle, and load_local picks them back up.
                NexKeyRuntimeNative.nexkeyruntime_license_destroy(existing.Handle);
                _handles.Remove(productId);
            }

            var handle = NexKeyRuntimeNative.nexkeyruntime_license_create();
            if (handle == IntPtr.Zero)
            {
                return null;
            }

            // Closure captures the still-being-built context via a local,
            // resolved once the object initializer below completes. Storing
            // the delegate on the context itself is what keeps it alive.
            NexKeyHandleContext? contextRef = null;
            NexKeyRuntimeLicenseCallback callback = (_, __) => contextRef?.BumpSyncSignal();

            var context = new NexKeyHandleContext
            {
                Handle = handle,
                Entry = entry,
                Callback = callback
            };
            contextRef = context;

            NexKeyRuntimeNative.nexkeyruntime_license_set_callback(handle, callback, IntPtr.Zero);

            if (NexKeyRuntimeNative.nexkeyruntime_license_set_product_data(handle, entry.ProductData) != NexKeyRuntimeResult.Ok)
            {
                NexKeyRuntimeNative.nexkeyruntime_license_destroy(handle);
                return null;
            }

            NexKeyRuntimeNative.nexkeyruntime_license_set_tenant_id(handle, entry.TenantId);
            NexKeyRuntimeNative.nexkeyruntime_license_set_variant(handle, entry.Variant);

            // "What the program calls itself" (activation_clients schema) —
            // the INTEGRATOR's name, never the per-product UUID.
            NexKeyRuntimeNative.nexkeyruntime_license_set_metadata(handle, "product", "mcnexus");

            var appVersion = AppBackendConfiguration.AppVersion;
            if (!string.IsNullOrEmpty(appVersion) && appVersion != "unknown")
            {
                NexKeyRuntimeNative.nexkeyruntime_license_set_metadata(handle, "appVersion", appVersion);
            }

            _handles[productId] = context;
            return context;
        }

        private async Task<T> RunOnQueueAsync<T>(Func<T> action)
        {
            await _gate.WaitAsync().ConfigureAwait(false);
            try
            {
                return await Task.Run(action).ConfigureAwait(false);
            }
            finally
            {
                _gate.Release();
            }
        }

        // MARK: - Activate

        public Task<bool> ActivateAsync(string productId, string licenseKey, string? productData, string machineFingerprint)
        {
            return RunOnQueueAsync(() =>
            {
                var context = Context(productId)
                    ?? throw new InvalidOperationException($"NexKeyRuntime has no configuration for product '{productId}'.");

                if (NexKeyRuntimeNative.nexkeyruntime_license_set_license_key(context.Handle, licenseKey) != NexKeyRuntimeResult.Ok)
                {
                    throw new InvalidOperationException("NexKeyRuntime rejected the license key.");
                }

                var result = NexKeyRuntimeNative.nexkeyruntime_license_activate(context.Handle);
                switch (result)
                {
                    case NexKeyRuntimeResult.Ok:
                    case NexKeyRuntimeResult.ProductActivated:
                        context.LastActivatedKey = licenseKey;
                        return true;
                    case NexKeyRuntimeResult.ActivationLimit:
                        throw new InvalidOperationException(
                            "No activations are available for this license. Deactivate another machine or contact support.");
                    case NexKeyRuntimeResult.LicenseKey:
                        throw new InvalidOperationException("This license key is not valid.");
                    case NexKeyRuntimeResult.LicenseExpired:
                        throw new InvalidOperationException("This license has expired.");
                    case NexKeyRuntimeResult.LicenseSuspended:
                        throw new InvalidOperationException("This license is suspended.");
                    case NexKeyRuntimeResult.LicenseRevoked:
                        throw new InvalidOperationException("This license has been revoked.");
                    default:
                        throw new InvalidOperationException($"NexKeyRuntime activation failed: {result}.");
                }
            });
        }

        // MARK: - Deactivate

        public Task DeactivateAsync(string productId, string? productData)
        {
            return RunOnQueueAsync(() =>
            {
                var context = Context(productId);
                if (context is null)
                {
                    return true;
                }

                var result = NexKeyRuntimeNative.nexkeyruntime_license_deactivate(context.Handle);
                if (result is NexKeyRuntimeResult.Ok or NexKeyRuntimeResult.NoReceipt or NexKeyRuntimeResult.ActivationNotFound)
                {
                    context.LastActivatedKey = null;
                }

                return true;
            });
        }

        // MARK: - Validate (local, no network)

        public Task<SdkLicenseStatus> ValidateAsync(string productId, string? productData)
        {
            return RunOnQueueAsync(() =>
            {
                var context = Context(productId);
                if (context is null)
                {
                    return SdkLicenseStatus.NotActivated;
                }

                NexKeyRuntimeNative.nexkeyruntime_license_load_local(context.Handle);
                var snapshot = NexKeyRuntimeLicenseSnapshot.Create();
                if (NexKeyRuntimeNative.nexkeyruntime_license_get_snapshot(context.Handle, ref snapshot) != NexKeyRuntimeResult.Ok)
                {
                    return SdkLicenseStatus.NotActivated;
                }

                return MapStatus(snapshot.status);
            });
        }

        // MARK: - Sync (forces a network round trip)

        public Task<SdkLicenseStatus> SyncActivationAsync(string productId, string? productData)
        {
            return RunOnQueueAsync(() =>
            {
                var context = Context(productId);
                if (context is null)
                {
                    return SdkLicenseStatus.NotActivated;
                }

                // request_sync is only synchronous when no poller thread is
                // running yet. Once one is (any interactive host with a
                // stored key), the call hands off to that thread and
                // returns immediately — reading the snapshot right after
                // would show pre-sync state. Ported from mc::License::syncNow():
                // wait for the callback, bounded at ~4s.
                var before = context.SnapshotSyncSignal();
                var requestResult = NexKeyRuntimeNative.nexkeyruntime_license_request_sync(context.Handle, 1);

                if (requestResult == NexKeyRuntimeResult.Ok)
                {
                    for (var i = 0; i < 80; i++)
                    {
                        if (context.SnapshotSyncSignal() != before)
                        {
                            break;
                        }
                        Thread.Sleep(50);
                    }
                }

                var snapshot = NexKeyRuntimeLicenseSnapshot.Create();
                if (NexKeyRuntimeNative.nexkeyruntime_license_get_snapshot(context.Handle, ref snapshot) != NexKeyRuntimeResult.Ok)
                {
                    return SyncFailureStatus(requestResult);
                }

                var status = MapStatus(snapshot.status);
                // No local state to report on. Whether that is a VERDICT or
                // just a broken call depends on why the sync could not run.
                return status == SdkLicenseStatus.NotActivated ? SyncFailureStatus(requestResult) : status;
            });
        }

        /// <summary>
        /// Separates "genuinely no activation on this machine" from "the
        /// call could not be made". <see cref="NexKeyRuntimeResult.InvalidConfig"/>
        /// is the one that matters most and looks least like a verdict:
        /// request_sync returns it when no license key is stored for the
        /// tenant, which is exactly the state right after a deactivation —
        /// that is a fact about the seat, not a failure.
        /// </summary>
        private static SdkLicenseStatus SyncFailureStatus(NexKeyRuntimeResult result)
        {
            return result switch
            {
                NexKeyRuntimeResult.InvalidConfig or NexKeyRuntimeResult.NoReceipt or NexKeyRuntimeResult.ActivationNotFound
                    => SdkLicenseStatus.DeactivatedRemotely,
                NexKeyRuntimeResult.Ok => SdkLicenseStatus.NotActivated,
                _ => SdkLicenseStatus.Unknown
            };
        }

        // MARK: - Activated key / ownership across relaunches

        public Task<string?> ActivatedKeyAsync(string productId)
        {
            return RunOnQueueAsync(() =>
            {
                if (!_handles.TryGetValue(productId, out var context) || context.LastActivatedKey is null)
                {
                    return (string?)null;
                }

                NexKeyRuntimeNative.nexkeyruntime_license_load_local(context.Handle);
                var snapshot = NexKeyRuntimeLicenseSnapshot.Create();
                if (NexKeyRuntimeNative.nexkeyruntime_license_get_snapshot(context.Handle, ref snapshot) != NexKeyRuntimeResult.Ok)
                {
                    return (string?)null;
                }

                // Only the two statuses meaning "no local state at all"
                // withhold the key. Everything else — suspended, revoked,
                // expired, seat released elsewhere — IS local state about
                // this key.
                return snapshot.status is NexKeyRuntimeLicenseStatus.NotActivated or NexKeyRuntimeLicenseStatus.Unknown
                    ? null
                    : context.LastActivatedKey;
            });
        }

        public Task<string?> LocalActivationIdentifierAsync(string productId)
        {
            return RunOnQueueAsync(() =>
            {
                var context = Context(productId);
                if (context is null)
                {
                    return (string?)null;
                }

                NexKeyRuntimeNative.nexkeyruntime_license_load_local(context.Handle);
                var snapshot = NexKeyRuntimeLicenseSnapshot.Create();
                if (NexKeyRuntimeNative.nexkeyruntime_license_get_snapshot(context.Handle, ref snapshot) != NexKeyRuntimeResult.Ok)
                {
                    return (string?)null;
                }

                var identifier = snapshot.ActivationId;
                return string.IsNullOrEmpty(identifier) ? null : identifier;
            });
        }

        public Task<bool> AdoptLocalActivationAsync(string productId, string licenseKey, string? activationId)
        {
            return RunOnQueueAsync(() =>
            {
                var context = Context(productId);
                if (context is null)
                {
                    return false;
                }

                if (context.LastActivatedKey is { } cached)
                {
                    return cached == licenseKey;
                }

                if (string.IsNullOrEmpty(activationId))
                {
                    return false;
                }

                NexKeyRuntimeNative.nexkeyruntime_license_load_local(context.Handle);
                var snapshot = NexKeyRuntimeLicenseSnapshot.Create();
                if (NexKeyRuntimeNative.nexkeyruntime_license_get_snapshot(context.Handle, ref snapshot) != NexKeyRuntimeResult.Ok)
                {
                    return false;
                }

                if (snapshot.ActivationId != activationId)
                {
                    return false;
                }

                context.LastActivatedKey = licenseKey;
                return true;
            });
        }

        // MARK: - Machine fingerprint

        public string MachineFingerprint()
        {
            return MachineGuidReader.Generate();
        }

        // MARK: - Status mapping

        private static SdkLicenseStatus MapStatus(NexKeyRuntimeLicenseStatus status)
        {
            return status switch
            {
                NexKeyRuntimeLicenseStatus.Active => SdkLicenseStatus.Active,
                NexKeyRuntimeLicenseStatus.OfflineGrace => SdkLicenseStatus.GenuineGracePeriod,
                NexKeyRuntimeLicenseStatus.Expired or NexKeyRuntimeLicenseStatus.OfflineGraceExpired => SdkLicenseStatus.Expired,
                NexKeyRuntimeLicenseStatus.Suspended => SdkLicenseStatus.Suspended,
                NexKeyRuntimeLicenseStatus.Revoked => SdkLicenseStatus.Revoked,
                // NOT Revoked, which this used to share a branch with in an
                // earlier draft. The license is fine; only this machine's
                // seat was released, and the user can take it back by
                // activating again.
                NexKeyRuntimeLicenseStatus.ActivationRemoved => SdkLicenseStatus.DeactivatedRemotely,
                NexKeyRuntimeLicenseStatus.NotActivated or NexKeyRuntimeLicenseStatus.Unknown => SdkLicenseStatus.NotActivated,
                _ => SdkLicenseStatus.Unknown
            };
        }
    }
}
