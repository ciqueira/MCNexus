#if ENABLE_NEXCONTROL
import Foundation
import AppKit
import ApplicationServices
import Combine

@MainActor
final class NexControlBridge: ObservableObject {
    static let shared = NexControlBridge()

    @Published private(set) var isRunning: Bool = false
    @Published private(set) var isMidiConnected: Bool = false
    @Published private(set) var midiDeviceName: String = "None"
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
    private var refreshProcess: Process?

    private init() {}

    func start() {
        guard !isRunning else { return }

        let ret = nexcontrol_hub_start(nil)
        if ret == 0 {
            isRunning = true
            startInspectorTracker()
            startRefreshDaemon()
        }
    }

    func stop() {
        guard isRunning else { return }
        trackerTask?.cancel()
        trackerTask = nil
        stopRefreshDaemon()
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
                let slot = (snap.last_cc >= 10 && snap.last_cc <= 33) ? Int(snap.last_cc - 9) : 0
                let deltaDir = snap.last_delta > 0 ? "+\(snap.last_delta) (Clockwise)" : "\(snap.last_delta) (Counter-clockwise)"
                let slotStr = slot > 0 ? "Slot \(slot)" : "CC \(snap.last_cc)"
                lastActivityText = "\(slotStr) -> \(deltaDir) [\(snap.total_ticks) ticks]"
            } else {
                lastActivityText = "No rotation detected"
            }
        }
    }

    private func startInspectorTracker() {
        trackerTask = Task.detached(priority: .background) { [weak self] in
            while !Task.isCancelled {
                let foundId = Self.scanResolveInspector()
                await MainActor.run { [weak self] in
                    guard let self = self, self.isRunning else { return }
                    if self.activeNodeId != foundId {
                        self.activeNodeId = foundId
                        nexcontrol_hub_set_active_node(foundId)
                    }
                    self.updateTelemetry()
                }
                try? await Task.sleep(nanoseconds: 150_000_000) // 150 ms
            }
        }
    }

    nonisolated private static func scanResolveInspector() -> UInt32 {
        var foundId: UInt32 = 0

        for app in NSWorkspace.shared.runningApplications {
            guard let name = app.localizedName, name.localizedCaseInsensitiveContains("resolve") else { continue }
            let appRef = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(appRef, 0.05) // 50ms protective timeout against UI hangs

            func searchElement(_ elem: AXUIElement, depth: Int) {
                if depth > 10 || foundId > 0 { return }

                var valRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(elem, kAXValueAttribute as CFString, &valRef) == .success, let valStr = valRef as? String {
                    if let range = valStr.range(of: "ID: ") {
                        let substr = valStr[range.upperBound...]
                        if let intVal = UInt32(substr.prefix(while: { $0.isNumber })) {
                            foundId = intVal
                            return
                        }
                    }
                }

                var childrenRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(elem, kAXChildrenAttribute as CFString, &childrenRef) == .success,
                   let children = childrenRef as? [AXUIElement] {
                    for child in children {
                        searchElement(child, depth: depth + 1)
                        if foundId > 0 { break }
                    }
                }
            }

            searchElement(appRef, depth: 0)
            break
        }

        return foundId
    }

    private func startRefreshDaemon() {
        guard refreshProcess == nil || !(refreshProcess?.isRunning ?? false) else { return }

        var scriptPath = Bundle.main.path(forResource: "resolve_refresh_daemon", ofType: "py")
        if scriptPath == nil {
            if let execURL = Bundle.main.executableURL {
                let resourcesURL = execURL.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/resolve_refresh_daemon.py")
                if FileManager.default.fileExists(atPath: resourcesURL.path) {
                    scriptPath = resourcesURL.path
                }
            }
        }
        if scriptPath == nil {
            if let envPath = ProcessInfo.processInfo.environment["MCNEXUS_REFRESH_DAEMON_PATH"],
               FileManager.default.fileExists(atPath: envPath) {
                scriptPath = envPath
            }
        }

        guard let path = scriptPath else { return }

        let pythonCandidates = [
            "/usr/bin/python3",
            "/usr/local/bin/python3",
            "/opt/homebrew/bin/python3"
        ]
        let pythonExecutable = pythonCandidates.first(where: { FileManager.default.fileExists(atPath: $0) }) ?? "/usr/bin/python3"

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: pythonExecutable)
        proc.arguments = [path]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice

        do {
            try proc.run()
            self.refreshProcess = proc
        } catch {}
    }

    private func stopRefreshDaemon() {
        if let proc = refreshProcess, proc.isRunning {
            proc.terminate()
        }
        refreshProcess = nil
    }
}
#endif
