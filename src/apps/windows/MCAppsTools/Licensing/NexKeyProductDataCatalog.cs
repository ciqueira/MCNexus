using System;
using System.Collections.Generic;

namespace MCAppsTools
{
    /// <summary>
    /// Configuration for one product's NexKeyRuntime handle:
    /// <c>set_tenant_id</c>/<c>set_variant</c>/<c>set_product_data</c>.
    /// Port of macOS's <c>NexKeyProductDataEntry</c>.
    /// </summary>
    public sealed record NexKeyProductDataEntry(string TenantId, string Variant, string ProductData);

    /// <summary>
    /// The signed ProductData blob a product needs, compiled at build time —
    /// port of macOS's <c>NexKeyProductDataCatalog</c>. NOT the only
    /// source: <see cref="NexKeyProductDataResolver"/> prefers whatever the
    /// backend returned on <c>validate-installation</c>/<c>sync-batch</c>
    /// and falls back here — a generation-2 tenant derives its ProductData
    /// per request and has no fixed blob to embed here at all.
    ///
    /// Compiled in rather than read from the environment, same reason as
    /// macOS: a GUI app launched from Explorer does not inherit shell env
    /// vars, so a env-var fallback that works from a terminal fails
    /// silently in the real app.
    /// </summary>
    public static class NexKeyProductDataCatalog
    {
        // Keyed by productID — the backend's product.productID (a UUID),
        // NOT the human-readable slug set_metadata("product", ...) reports
        // to the SDK. Confirmed against staging (26/08): validate-installation
        // for colorequalizer-oss returns this exact productID.
        private static readonly IReadOnlyDictionary<string, NexKeyProductDataEntry> Entries =
            new Dictionary<string, NexKeyProductDataEntry>(StringComparer.OrdinalIgnoreCase)
            {
                ["b5fa7f27-6ce7-40f1-bb92-106cd01e6e26"] = new NexKeyProductDataEntry(
                    "colorequalizer-oss",
                    "download:default",
                    // Verified byte-identical to
                    // MCPlugins/corePlugins/ColorEqualizer/src/productdata.nexkeydat
                    // and to the macOS catalog's entry for the same tenant
                    // (PLANO_CONSOLIDADO.md, 21/08).
                    "eyJmb3JtYXQiOiJuZXhrZXlydW50aW1lLXByb2R1Y3RkYXRhLXYxIiwia2V5SWQiOiJjb2xvcmVxdWFsaXplci1vc3Mtc3RhZ2luZy0yMDI2LTA4IiwicGF5bG9hZCI6ImV5SmlZWE5sVlhKc0lqb2lhSFIwY0hNNkx5OXpaR3N0YzNSaFoybHVaeTV0WTI1bGVIVnpMbUZ3Y0NJc0ltWnZjbTFoZEZabGNuTnBiMjRpT2pFc0ltbHpjM1ZsWkVGMElqb3hOemczTVRZd01qRTRMQ0pyWlhseWFXNW5JanBiZXlKclpYbEpaQ0k2SW1OdmJHOXlaWEYxWVd4cGVtVnlMVzl6Y3kxemRHRm5hVzVuTFRJd01qWXRNRGdpTENKd2RXSnNhV05MWlhraU9pSlJaa1pNVUhoTGRrbzRWVGxZZURKRVZHUjBOa051WWpKT09HSlVhWFpPVmtsVU9HVm5jV1UwUW5obkluMWRMQ0p1YjNSQlpuUmxjaUk2TUgwIiwic2lnbmF0dXJlIjoiYV9zQmdGMlBPQ2YzU3F2Z25KZjdNOGVBVFVxNVNPZlNXRkkwa1J4S3J2RE5VX3BfdkR1VEFrZ0Z1WTVpS3JVRk9PMkQzNmR4WGNYY0I0RElIZW1yQ1EifQ"
                )
            };

        public static NexKeyProductDataEntry? Entry(string productId)
        {
            return Entries.TryGetValue(productId, out var entry) ? entry : null;
        }
    }

    public interface INexKeyProductDataResolver
    {
        NexKeyProductDataEntry? Entry(string productId);
    }

    /// <summary>
    /// Backend cache first, compiled-in catalog second — that order, not
    /// the reverse. The catalog is a build-time snapshot; the cache holds
    /// what the backend sent RIGHT NOW, keyring rotations included.
    /// </summary>
    public sealed class NexKeyProductDataResolver : INexKeyProductDataResolver
    {
        private readonly NexKeyRuntimeConfigurationStore _store;

        public NexKeyProductDataResolver(NexKeyRuntimeConfigurationStore store)
        {
            _store = store;
        }

        public NexKeyProductDataEntry? Entry(string productId)
        {
            return _store.Load(productId) ?? NexKeyProductDataCatalog.Entry(productId);
        }
    }
}
