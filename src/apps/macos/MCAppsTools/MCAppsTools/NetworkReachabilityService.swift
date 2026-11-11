import Foundation
import Network
import Combine

/// Passive network reachability service utilizing NWPathMonitor on Darwin.
/// Emits state transitions without active probing (no ICMP/HTTP probes).
/// Preserves calm sync behavior by respecting cellular/expensive connections (path.isExpensive).
@MainActor
final class NetworkReachabilityService: ObservableObject {
    static let shared = NetworkReachabilityService()

    @Published private(set) var isConnected: Bool = true

    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.mcappstools.networkmonitor", qos: .utility)

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let satisfied = (path.status == .satisfied)
            Task { @MainActor in
                self?.isConnected = satisfied
            }
        }
        monitor.start(queue: monitorQueue)
    }

    deinit {
        monitor.cancel()
    }
}
