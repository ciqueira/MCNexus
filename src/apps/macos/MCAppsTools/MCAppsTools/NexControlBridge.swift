import Foundation
import AppKit
import Combine

@MainActor
final class NexControlBridge: ObservableObject {
    static let shared = NexControlBridge()

    struct ConnectedDeviceInfo: Identifiable {
        var id: String { portId }
        let portId: String
        let displayName: String
        let profileModel: String
        let profileTier: UInt8

        var tierLabel: String {
            switch profileTier {
            case 1: return "Custom"
            case 2: return "Homologated"
            default: return "Generic"
            }
        }
    }

    @Published private(set) var isRunning: Bool = false
    @Published private(set) var isMidiConnected: Bool = false
    @Published private(set) var midiDeviceName: String = "None"
    @Published private(set) var connectedDevices: [ConnectedDeviceInfo] = []
    @Published private(set) var isClientConnected: Bool = false
    @Published private(set) var clientPluginName: String = "None"
    @Published private(set) var activeNodeId: UInt32 = 0
    @Published private(set) var lastCC: UInt8 = 0
    @Published private(set) var lastDelta: Int8 = 0
    @Published private(set) var totalTicks: UInt64 = 0
    @Published private(set) var lastActivityText: String = "No recent activity"
    @Published private(set) var packetsReceived: UInt64 = 0
    @Published private(set) var deltasApplied: UInt64 = 0

    private var trackerTask: Task<Void, Never>?

    private init() {}

    func start() {
        guard !isRunning else { return }

        let ret = nexcontrol_hub_start(nil)
        if ret == 0 {
            isRunning = true
            startInspectorTracker()
        }
    }

    func stop() {
        guard isRunning else { return }
        trackerTask?.cancel()
        trackerTask = nil
        nexcontrol_hub_stop()
        isRunning = false
        isMidiConnected = false
        isClientConnected = false
        activeNodeId = 0
        lastActivityText = "Server stopped"
    }

    func updateTelemetry() {
        guard isRunning else { return }
        var snap = NexControlTelemetrySnapshot()
        snap.struct_size = MemoryLayout<NexControlTelemetrySnapshot>.size
        if nexcontrol_hub_get_telemetry(&snap) == 0 {
            packetsReceived = snap.packets_received
            deltasApplied = snap.deltas_applied
            isMidiConnected = (snap.midi_connected != 0)

            let devName = withUnsafePointer(to: &snap.midi_device_name) { ptr in
                ptr.withMemoryRebound(to: CChar.self, capacity: 64) { String(cString: $0) }
            }
            midiDeviceName = devName.isEmpty ? "None" : devName

            isClientConnected = (snap.client_connected != 0)
            let plugName = withUnsafePointer(to: &snap.client_plugin_name) { ptr in
                ptr.withMemoryRebound(to: CChar.self, capacity: 64) { String(cString: $0) }
            }
            clientPluginName = plugName.isEmpty ? "None" : plugName

            activeNodeId = snap.active_node_id

            lastCC = snap.last_cc
            lastDelta = snap.last_delta
            totalTicks = snap.total_ticks

            if snap.total_ticks > 0 {
                let deltaDir = snap.last_delta > 0 ? "+\(snap.last_delta) (CW)" : (snap.last_delta < 0 ? "\(snap.last_delta) (CCW)" : "Click")
                lastActivityText = "CC \(snap.last_cc) -> \(deltaDir) [\(snap.total_ticks) ticks]"
            } else {
                lastActivityText = "No rotation detected"
            }

            let devCount = nexcontrol_hub_get_device_count()
            var devices: [ConnectedDeviceInfo] = []
            for i in 0..<devCount {
                var devInfo = NexControlDeviceInfo()
                devInfo.struct_size = UInt32(MemoryLayout<NexControlDeviceInfo>.size)
                if nexcontrol_hub_get_device_info(i, &devInfo) == 0 {
                    let pid = withUnsafePointer(to: &devInfo.port_id) { ptr in
                        ptr.withMemoryRebound(to: CChar.self, capacity: 64) { String(cString: $0) }
                    }
                    let dname = withUnsafePointer(to: &devInfo.display_name) { ptr in
                        ptr.withMemoryRebound(to: CChar.self, capacity: 64) { String(cString: $0) }
                    }
                    let pmodel = withUnsafePointer(to: &devInfo.profile_model) { ptr in
                        ptr.withMemoryRebound(to: CChar.self, capacity: 64) { String(cString: $0) }
                    }
                    devices.append(ConnectedDeviceInfo(
                        portId: pid,
                        displayName: dname,
                        profileModel: pmodel,
                        profileTier: devInfo.profile_tier
                    ))
                }
            }
            connectedDevices = devices
        }
    }

    func reloadProfiles() {
        _ = nexcontrol_hub_reload_profiles(nil)
        updateTelemetry()
    }

    func setGenericEncoderMode(_ mode: UInt8) {
        _ = nexcontrol_hub_set_generic_encoder_mode(mode)
        updateTelemetry()
    }

    private func startInspectorTracker() {
        trackerTask = Task.detached(priority: .background) { [weak self] in
            while !Task.isCancelled {
                await MainActor.run { [weak self] in
                    guard let self = self, self.isRunning else { return }
                    self.updateTelemetry()
                }
                try? await Task.sleep(nanoseconds: 200_000_000) // 200 ms telemetry poll
            }
        }
    }
}
