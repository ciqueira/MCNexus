import Foundation
import AppKit

enum NexControlHubStatus: Equatable, Sendable {
    case stopped
    case running
    case startFailed(Int32)
}

struct NexControlTrayState: Equatable, Sendable {
    let status: NexControlHubStatus
    let isMidiConnected: Bool
    let isBlinkPhase: Bool
    let midiDeviceName: String

    static let initial = NexControlTrayState(
        status: .stopped,
        isMidiConnected: false,
        isBlinkPhase: false,
        midiDeviceName: "None"
    )
}

struct NexControlConnectedDeviceInfo: Identifiable, Equatable, Sendable {
    var id: String { portId }
    let portId: String
    let displayName: String
    let profileModel: String
    let profileTier: UInt8
    let isEnabled: Bool
    let connectionState: UInt8

    var tierLabel: String {
        switch profileTier {
        case 1: return "Custom"
        case 2: return "Homologated"
        default: return "Generic"
        }
    }
}

final class NexControlBridge {
    static let shared = NexControlBridge()

    private static let allowedPortsDefaultsKey = "nexcontrol.allowedMidiPorts"
    private static let genericEncoderModeDefaultsKey = "nexcontrol.genericEncoderMode"

    private let stateLock = NSLock()
    private let portsConfigLock = NSLock()
    private var status: NexControlHubStatus = .stopped
    private var trayState: NexControlTrayState = .initial
    private var trackerTask: Task<Void, Never>?
    private var onTrayStateChangedHandler: (@MainActor @Sendable (NexControlTrayState) -> Void)?

    private init() {}

    var isRunning: Bool {
        stateLock.withLock {
            if case .running = status { return true }
            return false
        }
    }

    func currentTrayState() -> NexControlTrayState {
        stateLock.withLock { trayState }
    }

    @MainActor
    func setTrayStateHandler(_ handler: @escaping @MainActor @Sendable (NexControlTrayState) -> Void) {
        stateLock.withLock {
            onTrayStateChangedHandler = handler
        }
        handler(currentTrayState())
    }

    func start() {
        let alreadyRunning = stateLock.withLock {
            if case .running = status { return true }
            return false
        }
        guard !alreadyRunning else { return }

        let savedPorts = UserDefaults.standard.stringArray(forKey: Self.allowedPortsDefaultsKey) ?? []
        for portId in savedPorts where !portId.isEmpty {
            _ = nexcontrol_hub_set_port_enabled(portId, 1)
        }
        _ = nexcontrol_hub_set_generic_encoder_mode(savedGenericEncoderMode())

        let ret = nexcontrol_hub_start(nil)
        if ret == 0 {
            let newState = NexControlTrayState(
                status: .running,
                isMidiConnected: false,
                isBlinkPhase: false,
                midiDeviceName: "None"
            )
            stateLock.withLock {
                status = .running
                trayState = newState
            }
            autoSelectFirstCompatibleDeviceIfNeeded()
            notifyTrayState(newState)
            startInspectorTracker()
        } else {
            let failedState = NexControlTrayState(
                status: .startFailed(ret),
                isMidiConnected: false,
                isBlinkPhase: false,
                midiDeviceName: "None"
            )
            stateLock.withLock {
                status = .startFailed(ret)
                trayState = failedState
            }
            notifyTrayState(failedState)
        }
    }

    func stop() {
        let taskToCancel: Task<Void, Never>? = stateLock.withLock {
            guard case .running = status else { return nil }
            let task = trackerTask
            trackerTask = nil
            status = .stopped
            trayState = .initial
            return task
        }

        guard taskToCancel != nil else { return }
        taskToCancel?.cancel()
        nexcontrol_hub_stop()
        notifyTrayState(.initial)
    }

    func reloadProfiles() {
        guard isRunning else { return }
        _ = nexcontrol_hub_reload_profiles(nil)
        if let snap = currentTelemetry() {
            let devName = decodeFixedCString(snap.midi_device_name)
            let updated = NexControlTrayState(
                status: .running,
                isMidiConnected: snap.midi_connected != 0,
                isBlinkPhase: false,
                midiDeviceName: devName.isEmpty ? "None" : devName
            )
            let changed = stateLock.withLock { () -> Bool in
                guard updated != trayState else { return false }
                trayState = updated
                return true
            }
            if changed {
                notifyTrayState(updated)
            }
        }
    }

    private func hasSavedPortConfiguration() -> Bool {
        UserDefaults.standard.object(forKey: Self.allowedPortsDefaultsKey) != nil
    }

    private func autoSelectFirstCompatibleDeviceIfNeeded() {
        guard isRunning, !hasSavedPortConfiguration() else { return }
        portsConfigLock.withLock {
            guard isRunning, !hasSavedPortConfiguration() else { return }
            let candidates = connectedDevicesSnapshot()
                .filter { ($0.profileTier == 1 || $0.profileTier == 2) && $0.connectionState == 0 && !$0.portId.isEmpty }
                .sorted { lhs, rhs in
                    if lhs.profileTier != rhs.profileTier {
                        return lhs.profileTier < rhs.profileTier
                    }
                    return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
                }
            guard let best = candidates.first else { return }
            let rc = nexcontrol_hub_set_port_enabled(best.portId, 1)
            if rc == 0 {
                UserDefaults.standard.set([best.portId], forKey: Self.allowedPortsDefaultsKey)
            }
        }
    }

    @discardableResult
    func setPortEnabled(_ portId: String, enabled: Bool) -> Int32 {
        portsConfigLock.withLock {
            guard isRunning else { return -1 }
            let rc = nexcontrol_hub_set_port_enabled(portId, enabled ? 1 : 0)
            if rc == 0 {
                var allowed = UserDefaults.standard.stringArray(forKey: Self.allowedPortsDefaultsKey) ?? []
                if enabled {
                    if !allowed.contains(portId) {
                        allowed.append(portId)
                    }
                } else {
                    allowed.removeAll { $0 == portId }
                }
                UserDefaults.standard.set(allowed, forKey: Self.allowedPortsDefaultsKey)
            }
            return rc
        }
    }

    func savedGenericEncoderMode() -> UInt8 {
        guard let raw = UserDefaults.standard.object(forKey: Self.genericEncoderModeDefaultsKey) as? Int,
              (0...4).contains(raw) else {
            return 4
        }
        return UInt8(raw)
    }

    @discardableResult
    func setGenericEncoderMode(_ mode: UInt8) -> Int32 {
        guard mode <= 4 else { return -1 }
        UserDefaults.standard.set(Int(mode), forKey: Self.genericEncoderModeDefaultsKey)
        return nexcontrol_hub_set_generic_encoder_mode(mode)
    }

    func currentTelemetry() -> NexControlTelemetrySnapshot? {
        guard isRunning else { return nil }
        var snap = NexControlTelemetrySnapshot()
        snap.struct_size = MemoryLayout<NexControlTelemetrySnapshot>.size
        guard nexcontrol_hub_get_telemetry(&snap) == 0 else { return nil }
        return snap
    }

    func connectedDevicesSnapshot() -> [NexControlConnectedDeviceInfo] {
        guard isRunning else { return [] }
        let devCount = nexcontrol_hub_get_device_count()
        var devices: [NexControlConnectedDeviceInfo] = []
        devices.reserveCapacity(Int(devCount))

        for i in 0..<devCount {
            var devInfo = NexControlDeviceInfo()
            devInfo.struct_size = UInt32(MemoryLayout<NexControlDeviceInfo>.size)
            if nexcontrol_hub_get_device_info(i, &devInfo) == 0 {
                devices.append(NexControlConnectedDeviceInfo(
                    portId: decodeFixedCString(devInfo.port_id),
                    displayName: decodeFixedCString(devInfo.display_name),
                    profileModel: decodeFixedCString(devInfo.profile_model),
                    profileTier: devInfo.profile_tier,
                    isEnabled: devInfo.is_enabled != 0,
                    connectionState: devInfo.connection_state
                ))
            }
        }
        return devices
    }

    private func startInspectorTracker() {
        let task = Task.detached(priority: .userInitiated) { [weak self] in
            var hasBaseline = false
            var lastObservedTicks: UInt64 = 0
            var lastObservedActivityMs: UInt64 = 0
            var lastActivityUptime: TimeInterval = 0
            var isBlinkPhase = false
            var blinkCycleCount: UInt = 0

            while !Task.isCancelled {
                guard let self = self, self.isRunning else { break }

                if !self.hasSavedPortConfiguration() {
                    self.autoSelectFirstCompatibleDeviceIfNeeded()
                }

                var snap = NexControlTelemetrySnapshot()
                snap.struct_size = MemoryLayout<NexControlTelemetrySnapshot>.size
                if nexcontrol_hub_get_telemetry(&snap) == 0 {
                    let isConnected = (snap.midi_connected != 0)
                    let rawDevName = decodeFixedCString(snap.midi_device_name)
                    let devName = (isConnected && !rawDevName.isEmpty) ? rawDevName : "None"

                    if !hasBaseline {
                        hasBaseline = true
                        lastObservedTicks = snap.total_ticks
                        lastObservedActivityMs = snap.last_activity_timestamp_ms
                    } else {
                        let hasNewTicks = (snap.total_ticks != lastObservedTicks)
                        let hasNewActivityMs = (snap.last_activity_timestamp_ms != lastObservedActivityMs)
                        if hasNewTicks || hasNewActivityMs {
                            lastActivityUptime = ProcessInfo.processInfo.systemUptime
                        }
                        lastObservedTicks = snap.total_ticks
                        lastObservedActivityMs = snap.last_activity_timestamp_ms
                    }

                    let now = ProcessInfo.processInfo.systemUptime
                    let isRecentlyActive = lastActivityUptime > 0 && (now - lastActivityUptime) < 0.35

                    if isConnected && isRecentlyActive {
                        blinkCycleCount += 1
                        if blinkCycleCount % 2 == 0 {
                            isBlinkPhase.toggle()
                        }
                    } else {
                        isBlinkPhase = false
                        blinkCycleCount = 0
                    }

                    let candidate = NexControlTrayState(
                        status: .running,
                        isMidiConnected: isConnected,
                        isBlinkPhase: isBlinkPhase,
                        midiDeviceName: devName
                    )

                    let changed = self.stateLock.withLock { () -> Bool in
                        guard case .running = self.status else { return false }
                        guard candidate != self.trayState else { return false }
                        self.trayState = candidate
                        return true
                    }

                    if changed {
                        self.notifyTrayState(candidate)
                    }
                }

                try? await Task.sleep(nanoseconds: 60_000_000)
            }
        }

        stateLock.withLock {
            trackerTask?.cancel()
            trackerTask = task
        }
    }

    private func notifyTrayState(_ state: NexControlTrayState) {
        let handler = stateLock.withLock { onTrayStateChangedHandler }
        guard let handler else { return }
        Task { @MainActor in
            handler(state)
        }
    }
}

private func decodeFixedCString<T>(_ tuple: T) -> String {
    withUnsafePointer(to: tuple) { ptr in
        ptr.withMemoryRebound(to: CChar.self, capacity: MemoryLayout<T>.size) { cStr in
            String(cString: cStr)
        }
    }
}
