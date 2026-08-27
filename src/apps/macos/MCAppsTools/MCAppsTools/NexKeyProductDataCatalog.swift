import Foundation

/// The signed ProductData blob a product needs, embedded at build time.
///
/// NO LONGER THE ONLY SOURCE. This used to be the whole story, with the
/// limitation written down and accepted: "every additional tenant needs a new
/// entry here and an app rebuild until a backend override path exists". That
/// path now exists — `NexKeyProductDataResolver` prefers what the backend
/// returned on validate-installation and falls back here. It had to: a
/// generation-2 tenant DERIVES its ProductData from its signing keyset per
/// request (Plano Tenant v2, §3.2) instead of storing it as a config field,
/// so there is no fixed blob to embed for one, and every v2 tenant would
/// otherwise be unactivatable no matter how many rebuilds it got.
///
/// What survives is the reason it is compiled in rather than read from the
/// environment (`PLANO_CONSOLIDADO.md`, decision of 21/08): a GUI app
/// launched from Finder does not inherit shell env vars, so a
/// `$NEXKEYRUNTIME_PRODUCT_FILE`-style fallback that works in a CLI test
/// fails silently in the real app — the same lesson the ColorEqualizer OFX
/// plugin's own `MCLicense.h` already paid for. This stays as the offline
/// floor for the tenant it covers, not as the mechanism for adding new ones.
///
/// `Codable` because `NexKeyRuntimeConfigurationStore` persists this exact
/// shape; `Equatable` because `NexKeyRuntimeProvider` compares a live
/// handle's entry against a freshly resolved one to notice a key rotation.
struct NexKeyProductDataEntry: Codable, Equatable, Sendable {
    let tenantId: String
    let variant: String
    let productData: String
}

enum NexKeyProductDataCatalog {
    /// Keyed by `productID`, the same identifier `AppProduct.productID` and
    /// the backend's `product.productID` already use — a UUID assigned by
    /// the backend's product config, NOT the human-readable slug the plugin
    /// reports to the SDK via `set_metadata("product", ...)` (that one is
    /// `"colorequalizer"`, a different value for a different purpose — see
    /// `MCLicense.h`'s `MC_NEXKEY_PRODUCT`). Confirmed against staging
    /// (26/08): `curl .../validate-installation` for `colorequalizer-oss`
    /// returns `product.productID = "b5fa7f27-6ce7-40f1-bb92-106cd01e6e26"`.
    private static let entries: [String: NexKeyProductDataEntry] = [
        "b5fa7f27-6ce7-40f1-bb92-106cd01e6e26": NexKeyProductDataEntry(
            tenantId: "colorequalizer-oss",
            variant: "download:default",
            // Verified byte-identical to
            // MCPlugins/corePlugins/ColorEqualizer/src/productdata.nexkeydat
            // (PLANO_CONSOLIDADO.md, 21/08) — same trust root the plugin
            // already compiles in, staging tenant colorequalizer-oss.
            productData: "eyJmb3JtYXQiOiJuZXhrZXlydW50aW1lLXByb2R1Y3RkYXRhLXYxIiwia2V5SWQiOiJjb2xvcmVxdWFsaXplci1vc3Mtc3RhZ2luZy0yMDI2LTA4IiwicGF5bG9hZCI6ImV5SmlZWE5sVlhKc0lqb2lhSFIwY0hNNkx5OXpaR3N0YzNSaFoybHVaeTV0WTI1bGVIVnpMbUZ3Y0NJc0ltWnZjbTFoZEZabGNuTnBiMjRpT2pFc0ltbHpjM1ZsWkVGMElqb3hOemczTVRZd01qRTRMQ0pyWlhseWFXNW5JanBiZXlKclpYbEpaQ0k2SW1OdmJHOXlaWEYxWVd4cGVtVnlMVzl6Y3kxemRHRm5hVzVuTFRJd01qWXRNRGdpTENKd2RXSnNhV05MWlhraU9pSlJaa1pNVUhoTGRrbzRWVGxZZURKRVZHUjBOa051WWpKT09HSlVhWFpPVmtsVU9HVm5jV1UwUW5obkluMWRMQ0p1YjNSQlpuUmxjaUk2TUgwIiwic2lnbmF0dXJlIjoiYV9zQmdGMlBPQ2YzU3F2Z25KZjdNOGVBVFVxNVNPZlNXRkkwa1J4S3J2RE5VX3BfdkR1VEFrZ0Z1WTVpS3JVRk9PMkQzNmR4WGNYY0I0RElIZW1yQ1EifQ"
        )
    ]

    static func entry(for productID: String) -> NexKeyProductDataEntry? {
        entries[productID]
    }
}
