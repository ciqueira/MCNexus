import Foundation

struct SDKProductConfiguration: Hashable, Sendable {
    let productID: String
    let productData: String
}

struct AppProduct: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let name: String
    let productID: String
    let purchaseURL: URL?

    nonisolated init(
        name: String,
        productID: String,
        purchaseURL: URL? = nil
    ) {
        self.id = productID
        self.name = name
        self.productID = productID
        self.purchaseURL = purchaseURL
    }

    nonisolated var displayName: String {
        name
    }
}

enum AppProductCatalog {
    /// Returns an empty list — the product roster is no longer configurable
    /// upfront. The backend's `validate-installation` response is the source
    /// of truth for product identity; the UI shows the activation form with
    /// no preselected product and updates the license item once the backend
    /// resolves the key.
    nonisolated static func configuredProducts() -> [AppProduct] {
        []
    }

    nonisolated static func product(for productID: String) -> AppProduct {
        AppProduct(name: productDisplayName(for: productID), productID: productID)
    }

    nonisolated private static func productDisplayName(for productID: String) -> String {
        "--"
    }
}
