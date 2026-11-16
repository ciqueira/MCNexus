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

    private var activityMenuItem: NSMenuItem?
    private var accumulatedMenuItem: NSMenuItem?
    private var liveMenuTimer: Timer?
    private var lastMenuTicks: UInt64 = 0

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
        menu.addItem(makeLabelItem("MIDI Hardware"))
        if let snap = telemetry, snap.midi_connected != 0 {
            let activeName = decodeFixedString(snap.midi_device_name)
            menu.addItem(makeLabelItem("  Active: \(activeName.isEmpty ? "Unknown" : activeName)"))
            for dev in devices {
                menu.addItem(makeLabelItem("  • \(dev.displayName) [\(dev.tierLabel)]"))
            }
        } else {
            menu.addItem(makeLabelItem("  Device: None detected"))
        }

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
        let (activityLine, accumulatedLine) = formatActivityLines(from: telemetry, status: state.status)
        let activityItem = makeLabelItem(activityLine)
        menu.addItem(activityItem)
        activityMenuItem = activityItem

        let accumulatedItem = makeLabelItem(accumulatedLine ?? "")
        accumulatedItem.isHidden = (accumulatedLine == nil)
        menu.addItem(accumulatedItem)
        accumulatedMenuItem = accumulatedItem
        lastMenuTicks = telemetry?.total_ticks ?? 0
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
        let ticks = telemetry?.total_ticks ?? 0
        guard ticks != lastMenuTicks else { return }
        lastMenuTicks = ticks

        let (activityLine, accumulatedLine) = formatActivityLines(from: telemetry, status: state.status)
        activityMenuItem?.title = activityLine
        if let accumulatedLine {
            accumulatedMenuItem?.title = accumulatedLine
            accumulatedMenuItem?.isHidden = false
        } else {
            accumulatedMenuItem?.isHidden = true
        }
    }

    private func formatActivityLines(
        from snap: NexControlTelemetrySnapshot?,
        status: NexControlHubStatus
    ) -> (String, String?) {
        guard status == .running else {
            return ("  Server stopped", nil)
        }
        guard let snap, snap.total_ticks > 0 else {
            return ("  No rotation detected", nil)
        }
        let deltaDir = snap.last_delta > 0
            ? "+\(snap.last_delta) (CW)"
            : (snap.last_delta < 0 ? "\(snap.last_delta) (CCW)" : "Click")
        let activity = "  CC \(snap.last_cc) -> \(deltaDir) [\(snap.total_ticks) ticks]"
        let accumulated = "  Accumulated total: \(snap.total_ticks) ticks"
        return (activity, accumulated)
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

private extension NSBezierPath {
    func also(_ block: (NSBezierPath) -> Void) {
        block(self)
    }
}
