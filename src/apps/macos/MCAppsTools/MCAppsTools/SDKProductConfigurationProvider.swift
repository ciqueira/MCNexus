import Foundation
#if DEBUG
import OSLog
#endif

protocol SDKProductConfigurationProviding: Sendable {
    func sdkConfiguration(for product: AppProduct) -> SDKProductConfiguration?
}

struct LocalSDKProductConfigurationProvider: SDKProductConfigurationProviding {
    #if DEBUG
    private static let logger = Logger(subsystem: "MCAppsTools", category: "SDKConfig")
    #endif

    private let productCredentialStore: ProductCredentialStore

    init(productCredentialStore: ProductCredentialStore = ProductCredentialStore()) {
        self.productCredentialStore = productCredentialStore
    }

    func sdkConfiguration(for product: AppProduct) -> SDKProductConfiguration? {
        if let productData = try? productCredentialStore.loadProductData(for: product.productID),
           !productData.isEmpty {
            #if DEBUG
            Self.logger.debug("Loaded productData from local encrypted storage for productID=\(product.productID, privacy: .public) len=\(productData.count, privacy: .public)")
            #endif
            return SDKProductConfiguration(productID: product.productID, productData: productData)
        }

        #if DEBUG
        Self.logger.error("No productData in local encrypted storage for productID=\(product.productID, privacy: .public)")
        #endif
        return nil
    }
}
