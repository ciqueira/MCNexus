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
    @Published private(set) var currentTrayIcon: NSImage

    private let iconDisconnected = HubIconFactory.makeIcon(isConnected: false, isBlinkPhase: false)
    private let iconConnectedIdle = HubIconFactory.makeIcon(isConnected: true, isBlinkPhase: false)
    private let iconConnectedActive = HubIconFactory.makeIcon(isConnected: true, isBlinkPhase: true)

    private var lastObservedTicks: UInt64 = 0
    private var lastObservedActivityMs: UInt64 = 0
    private var lastActivityUptime: TimeInterval = 0
    private var isBlinkPhase: Bool = false
    private var blinkCycleCount: UInt = 0

    private var trackerTask: Task<Void, Never>?

    private init() {
        _currentTrayIcon = Published(initialValue: HubIconFactory.makeIcon(isConnected: false, isBlinkPhase: false))
    }

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
        lastObservedTicks = 0
        lastObservedActivityMs = 0
        isBlinkPhase = false
        blinkCycleCount = 0
        currentTrayIcon = iconDisconnected
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

            // Check for activity (rotation of knobs or button clicks)
            let hasNewTicks = (snap.total_ticks != lastObservedTicks && lastObservedTicks != 0)
            let hasNewActivityMs = (snap.last_activity_timestamp_ms != lastObservedActivityMs && lastObservedActivityMs != 0)

            if hasNewTicks || hasNewActivityMs {
                lastActivityUptime = ProcessInfo.processInfo.systemUptime
            }
            lastObservedTicks = snap.total_ticks
            lastObservedActivityMs = snap.last_activity_timestamp_ms

            let now = ProcessInfo.processInfo.systemUptime
            let isRecentlyActive = (now - lastActivityUptime) < 0.35

            if isMidiConnected && isRecentlyActive {
                blinkCycleCount += 1
                if blinkCycleCount % 2 == 0 {
                    isBlinkPhase.toggle()
                }
            } else {
                isBlinkPhase = false
                blinkCycleCount = 0
            }

            let desiredIcon: NSImage
            if !isMidiConnected {
                desiredIcon = iconDisconnected
            } else if isBlinkPhase {
                desiredIcon = iconConnectedActive
            } else {
                desiredIcon = iconConnectedIdle
            }

            if currentTrayIcon !== desiredIcon {
                currentTrayIcon = desiredIcon
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
                try? await Task.sleep(nanoseconds: 60_000_000) // 60 ms telemetry poll
            }
        }
    }
}

// MARK: - Hub Tray Icon Factory

enum HubIconFactory {
    static let iconSize = NSSize(width: 18, height: 18)

    static func makeIcon(isConnected: Bool, isBlinkPhase: Bool) -> NSImage {
        let image = NSImage(size: iconSize, flipped: false) { _ in
            let appearance = NSAppearance.currentDrawing()
            let isDark = (appearance.bestMatch(from: [.darkAqua, .aqua])
                ?? NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])) == .darkAqua

            let pad: CGFloat = 1.0
            let elem: CGFloat = 6.5
            let gap: CGFloat = 3.0
            let cornerRadius: CGFloat = 1.2

            let x0 = pad
            let x1 = pad + elem + gap
            let y0 = pad               // bottom row (unflipped AppKit: y=0 is bottom)
            let y1 = pad + elem + gap  // top row

            let yellowColor: NSColor
            let blueColor: NSColor
            let greenColor: NSColor

            if isConnected {
                yellowColor = NSColor(srgbRed: 0xFA/255.0, green: 0xB8/255.0, blue: 0x47/255.0, alpha: 1.0)
                blueColor   = NSColor(srgbRed: 0x5C/255.0, green: 0xAF/255.0, blue: 0xFA/255.0, alpha: 1.0)
                greenColor  = NSColor(srgbRed: 0x5E/255.0, green: 0xE0/255.0, blue: 0xA1/255.0, alpha: 1.0)
            } else {
                yellowColor = NSColor(white: 0.68, alpha: 0.85)
                blueColor   = NSColor(white: 0.58, alpha: 0.85)
                greenColor  = NSColor(white: 0.72, alpha: 0.85)
            }

            // Dot color:
            // In dark theme: idle is White (#FFFFFF), active alternates to Black (#000000)
            // In light theme: idle is #222222, active alternates to White (#FFFFFF)
            let dotColor: NSColor
            if isDark {
                dotColor = isBlinkPhase ? NSColor.black : NSColor.white
            } else {
                let darkGray = NSColor(srgbRed: 0x22/255.0, green: 0x22/255.0, blue: 0x22/255.0, alpha: 1.0)
                dotColor = isBlinkPhase ? NSColor.white : darkGray
            }

            // 1. Top-Left: Circle (Bolinha) -> at (x0, y1)
            let circleRect = NSRect(x: x0, y: y1, width: elem, height: elem)
            let circlePath = NSBezierPath(ovalIn: circleRect)
            dotColor.setFill()
            circlePath.fill()

            // 2. Top-Right: Yellow square -> at (x1, y1)
            let trRect = NSRect(x: x1, y: y1, width: elem, height: elem)
            let trPath = NSBezierPath(roundedRect: trRect, xRadius: cornerRadius, yRadius: cornerRadius)
            yellowColor.setFill()
            trPath.fill()

            // 3. Bottom-Left: Blue square -> at (x0, y0)
            let blRect = NSRect(x: x0, y: y0, width: elem, height: elem)
            let blPath = NSBezierPath(roundedRect: blRect, xRadius: cornerRadius, yRadius: cornerRadius)
            blueColor.setFill()
            blPath.fill()

            // 4. Bottom-Right: Green square -> at (x1, y0)
            let brRect = NSRect(x: x1, y: y0, width: elem, height: elem)
            let brPath = NSBezierPath(roundedRect: brRect, xRadius: cornerRadius, yRadius: cornerRadius)
            greenColor.setFill()
            brPath.fill()

            return true
        }

        image.isTemplate = false
        return image
    }
}
