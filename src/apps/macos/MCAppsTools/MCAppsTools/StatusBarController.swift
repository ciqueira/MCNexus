import Foundation
import AppKit

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    static let shared = StatusBarController()

    private var statusItem: NSStatusItem?
    private let menu = NSMenu()

    private var currentTrayState: NexControlTrayState = .initial
    private var iconCache: [IconKey: NSImage] = [:]
    private var appearanceObservation: NSKeyValueObservation?

    private struct ActivitySignature: Equatable {
        let status: NexControlHubStatus
        let selectedGenericMode: UInt8
        let hasGenericDevice: Bool
        let totalTicks: UInt64
        let lastActivityTimestampMs: UInt64
        let lastCc: UInt8
        let lastDelta: Int8
        let lastMatched: UInt8
        let lastEncoderMode: UInt8
        let lastMidiChannel: UInt8
        let lastBank: UInt8
    }

    private var activityMenuItem: NSMenuItem?
    private var accumulatedMenuItem: NSMenuItem?
    private var liveMenuTimer: Timer?
    private var lastActivitySignature: ActivitySignature?

    var openMainWindowHandler: (() -> Void)?

    private struct IconKey: Hashable {
        let isConnected: Bool
        let isBlinkPhase: Bool
        let isDark: Bool
    }

    private override init() {
        super.init()
    }

    func install() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.isVisible = true
        menu.delegate = self
        menu.autoenablesItems = false
        item.menu = menu
        statusItem = item

        if let button = item.button {
            appearanceObservation = button.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in
                    self?.refreshStatusButton()
                }
            }
        }

        NexControlBridge.shared.setTrayStateHandler { [weak self] state in
            self?.applyTrayState(state)
        }
    }

    func uninstall() {
        stopLiveMenuTimer()
        appearanceObservation?.invalidate()
        appearanceObservation = nil
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    private func applyTrayState(_ state: NexControlTrayState) {
        currentTrayState = state
        refreshStatusButton()
    }

    private func isDarkMenuBar() -> Bool {
        let appearance = statusItem?.button?.effectiveAppearance ?? NSApp.effectiveAppearance
        return appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    private func refreshStatusButton() {
        guard let button = statusItem?.button else { return }
        let isDark = isDarkMenuBar()
        let key = IconKey(
            isConnected: currentTrayState.isMidiConnected,
            isBlinkPhase: currentTrayState.isBlinkPhase,
            isDark: isDark
        )
        let image: NSImage
        if let cached = iconCache[key] {
            image = cached
        } else {
            image = HubIconFactory.makeIcon(
                isConnected: key.isConnected,
                isBlinkPhase: key.isBlinkPhase,
                isDark: key.isDark
            )
            iconCache[key] = image
        }
        if button.image !== image {
            button.image = image
        }
        let tip = buildTooltip(for: currentTrayState)
        if button.toolTip != tip {
            button.toolTip = tip
        }
    }

    private func buildTooltip(for state: NexControlTrayState) -> String {
        switch state.status {
        case .startFailed(let code):
            return "MCNexus - NexControl Hub error (\(code))"
        case .stopped:
            return "MCNexus - NexControl Hub (Paused)"
        case .running:
            if state.isMidiConnected && state.midiDeviceName != "None" {
                return "MCNexus - MIDI: \(state.midiDeviceName)"
            } else if state.isMidiConnected {
                return "MCNexus - MIDI Connected"
            }
            return "MCNexus - NexControl MIDI Hub (No device)"
        }
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        stopLiveMenuTimer()
        rebuildMenu()
        startLiveMenuTimer()
    }

    func menuDidClose(_ menu: NSMenu) {
        stopLiveMenuTimer()
        activityMenuItem = nil
        accumulatedMenuItem = nil
        lastActivitySignature = nil
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        let state = NexControlBridge.shared.currentTrayState()
        let telemetry = NexControlBridge.shared.currentTelemetry()
        let devices = NexControlBridge.shared.connectedDevicesSnapshot()

        // 1. Header
        menu.addItem(makeLabelItem("NexControl MIDI Hub"))
        switch state.status {
        case .stopped:
            menu.addItem(makeLabelItem("  Status: Paused"))
        case .startFailed(let code):
            menu.addItem(makeLabelItem("  Status: Start failed (code \(code))"))
        case .running:
            break
        }
        menu.addItem(.separator())

        // 2. MIDI Hardware
        menu.addItem(makeLabelItem("MIDI Devices"))
        if let snap = telemetry, snap.midi_connected != 0 {
            let activeName = decodeFixedString(snap.midi_device_name)
            menu.addItem(makeLabelItem("  Active: \(activeName.isEmpty ? "Unknown" : activeName)"))
        } else if !devices.isEmpty {
            menu.addItem(makeLabelItem("  Active: None (click a device to enable)"))
        } else {
            menu.addItem(makeLabelItem("  Device: None detected"))
        }

        for dev in devices {
            let isChecked = dev.isEnabled || (dev.connectionState == 1)
            let statusSuffix = (dev.connectionState == 2) ? "\(dev.tierLabel) - Busy" : dev.tierLabel
            let item = NSMenuItem(
                title: "\(dev.displayName) [\(statusSuffix)]",
                action: #selector(handleToggleDevice(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.isEnabled = (state.status == .running)
            item.state = isChecked ? .on : .off
            item.representedObject = DeviceToggleTarget(portId: dev.portId, nextEnabled: !isChecked)
            menu.addItem(item)
        }

        let savedGenericMode = NexControlBridge.shared.savedGenericEncoderMode()
        let hasGenericDevice = devices.contains { $0.profileTier == 3 && ($0.isEnabled || $0.connectionState == 1) }

        let modeSubmenuItem = NSMenuItem(title: "Generic Encoder Mode", action: nil, keyEquivalent: "")
        let modeSubmenu = NSMenu()
        modeSubmenu.autoenablesItems = false
        let modeOptions: [(UInt8, String)] = [
            (4, "Auto-Detect"),
            (3, "Absolute (0-127)"),
            (0, "Two's Complement (Relative)"),
            (1, "Binary Offset 64 (Relative)"),
            (2, "Sign-Magnitude / Mackie (Relative)")
        ]
        for (modeValue, modeTitle) in modeOptions {
            let optItem = NSMenuItem(
                title: modeTitle,
                action: #selector(handleSelectGenericMode(_:)),
                keyEquivalent: ""
            )
            optItem.target = self
            optItem.tag = Int(modeValue)
            optItem.state = (savedGenericMode == modeValue) ? .on : .off
            modeSubmenu.addItem(optItem)
        }
        if savedGenericMode == 4 {
            modeSubmenu.addItem(.separator())
            modeSubmenu.addItem(makeLabelItem("Tip: Turn a knob CW & CCW to detect"))
        }
        modeSubmenuItem.submenu = modeSubmenu
        menu.addItem(modeSubmenuItem)

        let reloadItem = NSMenuItem(
            title: "Reload Custom Profiles",
            action: #selector(handleReloadProfiles),
            keyEquivalent: ""
        )
        reloadItem.target = self
        reloadItem.isEnabled = (state.status == .running)
        menu.addItem(reloadItem)
        menu.addItem(.separator())

        // 3. Knob Activity
        menu.addItem(makeLabelItem("Knob Activity"))
        let (activityLine, accumulatedLine) = formatActivityLines(
            from: telemetry,
            status: state.status,
            selectedGenericMode: savedGenericMode,
            hasGenericDevice: hasGenericDevice
        )
        let activityItem = makeLabelItem(activityLine)
        menu.addItem(activityItem)
        activityMenuItem = activityItem

        let accumulatedItem = makeLabelItem(accumulatedLine ?? "")
        accumulatedItem.isHidden = (accumulatedLine == nil)
        menu.addItem(accumulatedItem)
        accumulatedMenuItem = accumulatedItem
        lastActivitySignature = makeActivitySignature(
            telemetry: telemetry,
            status: state.status,
            selectedGenericMode: savedGenericMode,
            hasGenericDevice: hasGenericDevice
        )
        menu.addItem(.separator())

        // 4. Hub Toggle
        let isRunning = (state.status == .running)
        let toggleItem = NSMenuItem(
            title: isRunning ? "Pause MIDI Hub" : "Start MIDI Hub",
            action: #selector(handleToggleHub),
            keyEquivalent: ""
        )
        toggleItem.target = self
        menu.addItem(toggleItem)
        menu.addItem(.separator())

        // 5. Open & Quit
        let openItem = NSMenuItem(
            title: "Open MCNexus",
            action: #selector(handleOpenMainWindow),
            keyEquivalent: ""
        )
        openItem.target = self
        menu.addItem(openItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit MCNexus",
            action: #selector(handleQuit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func startLiveMenuTimer() {
        let timer = Timer(timeInterval: 0.15, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshLiveActivityInMenu()
            }
        }
        RunLoop.main.add(timer, forMode: .eventTracking)
        liveMenuTimer = timer
    }

    private func stopLiveMenuTimer() {
        liveMenuTimer?.invalidate()
        liveMenuTimer = nil
    }

    private func refreshLiveActivityInMenu() {
        let state = NexControlBridge.shared.currentTrayState()
        let telemetry = NexControlBridge.shared.currentTelemetry()
        let devices = NexControlBridge.shared.connectedDevicesSnapshot()
        let savedGenericMode = NexControlBridge.shared.savedGenericEncoderMode()
        let hasGenericDevice = devices.contains { $0.profileTier == 3 && ($0.isEnabled || $0.connectionState == 1) }

        let sig = makeActivitySignature(
            telemetry: telemetry,
            status: state.status,
            selectedGenericMode: savedGenericMode,
            hasGenericDevice: hasGenericDevice
        )
        guard sig != lastActivitySignature else { return }
        lastActivitySignature = sig

        let (activityLine, accumulatedLine) = formatActivityLines(
            from: telemetry,
            status: state.status,
            selectedGenericMode: savedGenericMode,
            hasGenericDevice: hasGenericDevice
        )
        activityMenuItem?.title = activityLine
        if let accumulatedLine {
            accumulatedMenuItem?.title = accumulatedLine
            accumulatedMenuItem?.isHidden = false
        } else {
            accumulatedMenuItem?.isHidden = true
        }
    }

    private func makeActivitySignature(
        telemetry: NexControlTelemetrySnapshot?,
        status: NexControlHubStatus,
        selectedGenericMode: UInt8,
        hasGenericDevice: Bool
    ) -> ActivitySignature {
        ActivitySignature(
            status: status,
            selectedGenericMode: selectedGenericMode,
            hasGenericDevice: hasGenericDevice,
            totalTicks: telemetry?.total_ticks ?? 0,
            lastActivityTimestampMs: telemetry?.last_activity_timestamp_ms ?? 0,
            lastCc: telemetry?.last_cc ?? 0,
            lastDelta: telemetry?.last_delta ?? 0,
            lastMatched: telemetry?.last_matched ?? 0,
            lastEncoderMode: telemetry?.last_encoder_mode ?? 0,
            lastMidiChannel: telemetry?.last_midi_channel ?? 0,
            lastBank: telemetry?.last_bank ?? 0
        )
    }

    private func formatActivityLines(
        from snap: NexControlTelemetrySnapshot?,
        status: NexControlHubStatus,
        selectedGenericMode: UInt8,
        hasGenericDevice: Bool
    ) -> (String, String?) {
        guard status == .running else {
            return ("  Server stopped", nil)
        }
        guard let snap, (snap.total_ticks > 0 || snap.last_activity_timestamp_ms > 0) else {
            let hint = (selectedGenericMode == 4 && hasGenericDevice)
                ? "  Auto-Detect: Turn a knob CW & CCW"
                : nil
            return ("  No rotation detected", hint)
        }
        if snap.last_matched == 0 {
            return (
                "  Control \(snap.last_cc) -> Unmatched",
                "  Ch \(snap.last_midi_channel) · No matching rule"
            )
        }
        let ticksStr = snap.total_ticks == 1 ? "1 tick" : "\(snap.total_ticks) ticks"
        if snap.last_delta == 0 {
            return (
                "  Control \(snap.last_cc) -> Click [\(ticksStr)]",
                "  Ch \(snap.last_midi_channel) · Matched"
            )
        }
        let deltaDir = snap.last_delta > 0
            ? "+\(snap.last_delta) (CW)"
            : "\(snap.last_delta) (CCW)"
        let modeLabel: String
        switch snap.last_encoder_mode {
        case 0: modeLabel = "Two's Complement"
        case 1: modeLabel = "Binary Offset 64"
        case 2: modeLabel = "Sign-Magnitude"
        case 3: modeLabel = "Absolute"
        default: modeLabel = "Unknown"
        }
        let detail = snap.last_bank > 0
            ? "  Ch \(snap.last_midi_channel) · B\(snap.last_bank) · \(modeLabel)"
            : "  Ch \(snap.last_midi_channel) · \(modeLabel)"
        return ("  CC \(snap.last_cc) -> \(deltaDir) [\(ticksStr)]", detail)
    }

    private func makeLabelItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func decodeFixedString<T>(_ tuple: T) -> String {
        withUnsafePointer(to: tuple) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: MemoryLayout<T>.size) { cStr in
                String(cString: cStr)
            }
        }
    }

    // MARK: - Actions

    @objc private func handleReloadProfiles() {
        NexControlBridge.shared.reloadProfiles()
    }

    @objc private func handleSelectGenericMode(_ sender: NSMenuItem) {
        let mode = UInt8(clamping: sender.tag)
        NexControlBridge.shared.setGenericEncoderMode(mode)
        rebuildMenu()
    }

    @objc private func handleToggleDevice(_ sender: NSMenuItem) {
        guard let target = sender.representedObject as? DeviceToggleTarget else { return }
        Task.detached(priority: .userInitiated) {
            _ = NexControlBridge.shared.setPortEnabled(target.portId, enabled: target.nextEnabled)
        }
    }

    @objc private func handleToggleHub() {
        if NexControlBridge.shared.isRunning {
            NexControlBridge.shared.stop()
        } else {
            NexControlBridge.shared.start()
        }
    }

    @objc private func handleOpenMainWindow() {
        openMainWindowHandler?()
    }

    @objc private func handleQuit() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - Hub Tray Icon Factory

enum HubIconFactory {
    static let iconSize = NSSize(width: 18, height: 18)

    static func makeIcon(isConnected: Bool, isBlinkPhase: Bool, isDark: Bool) -> NSImage {
        let image = NSImage(size: iconSize, flipped: false) { _ in
            let pad: CGFloat = 1.0
            let elem: CGFloat = 6.5
            let gap: CGFloat = 3.0
            let cornerRadius: CGFloat = 1.2

            let x0 = pad
            let x1 = pad + elem + gap
            let y0 = pad
            let y1 = pad + elem + gap

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

            let dotColor: NSColor
            if isDark {
                dotColor = isBlinkPhase ? NSColor.black : NSColor.white
            } else {
                let darkGray = NSColor(srgbRed: 0x22/255.0, green: 0x22/255.0, blue: 0x22/255.0, alpha: 1.0)
                dotColor = isBlinkPhase ? NSColor.white : darkGray
            }

            // 1. Top-Left: Activity Dot
            NSBezierPath(ovalIn: NSRect(x: x0, y: y1, width: elem, height: elem)).also { path in
                dotColor.setFill()
                path.fill()
            }

            // 2. Top-Right: Yellow square
            NSBezierPath(roundedRect: NSRect(x: x1, y: y1, width: elem, height: elem), xRadius: cornerRadius, yRadius: cornerRadius).also { path in
                yellowColor.setFill()
                path.fill()
            }

            // 3. Bottom-Left: Blue square
            NSBezierPath(roundedRect: NSRect(x: x0, y: y0, width: elem, height: elem), xRadius: cornerRadius, yRadius: cornerRadius).also { path in
                blueColor.setFill()
                path.fill()
            }

            // 4. Bottom-Right: Green square
            NSBezierPath(roundedRect: NSRect(x: x1, y: y0, width: elem, height: elem), xRadius: cornerRadius, yRadius: cornerRadius).also { path in
                greenColor.setFill()
                path.fill()
            }

            return true
        }

        image.isTemplate = false
        return image
    }
}

private final class DeviceToggleTarget: NSObject {
    let portId: String
    let nextEnabled: Bool

    init(portId: String, nextEnabled: Bool) {
        self.portId = portId
        self.nextEnabled = nextEnabled
    }
}

private extension NSBezierPath {
    func also(_ block: (NSBezierPath) -> Void) {
        block(self)
    }
}
