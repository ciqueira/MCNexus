//
//  MCAppsToolsApp.swift
//  MCAppsTools
//
//  Created by Magno Ciqueira on 28/04/2026.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

#if os(macOS)
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var activity: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Prevent App Nap while MIDI hub is running
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .latencyCritical],
            reason: "NexControl MIDI Streaming Hub"
        )

        StatusBarController.shared.openMainWindowHandler = { [weak self] in
            self?.openOrRestoreMainWindow()
        }
        StatusBarController.shared.install()
        NexControlBridge.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        StatusBarController.shared.uninstall()
        NexControlBridge.shared.stop()
        if let act = activity {
            ProcessInfo.processInfo.endActivity(act)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false // Keep app alive in menu bar
    }

    private func openOrRestoreMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.canBecomeMain && !$0.className.contains("StatusBar") }) {
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.makeKeyAndOrderFront(nil)
            return
        }
        if let url = URL(string: "mcnexus://open") {
            NSWorkspace.shared.open(url)
        }
    }
}
#endif

@main
struct MCAppToolsApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
                .handlesExternalEvents(preferring: Set(arrayLiteral: "*"), allowing: Set(arrayLiteral: "*"))
        }
        .windowResizability(.contentSize)
        .handlesExternalEvents(matching: Set(arrayLiteral: "*"))
    }
}
