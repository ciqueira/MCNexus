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
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var activity: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Prevent App Nap while MIDI hub is running
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .latencyCritical],
            reason: "NexControl MIDI Streaming Hub"
        )
        NexControlBridge.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        NexControlBridge.shared.stop()
        if let act = activity {
            ProcessInfo.processInfo.endActivity(act)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false // Keep app alive in menu bar
    }
}
#endif

@main
struct MCAppToolsApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var nexControl = NexControlBridge.shared
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
                .handlesExternalEvents(preferring: Set(arrayLiteral: "*"), allowing: Set(arrayLiteral: "*"))
        }
        .windowResizability(.contentSize)
        .handlesExternalEvents(matching: Set(arrayLiteral: "*"))

        #if os(macOS)
        MenuBarExtra("MCNexus", systemImage: "dial.low.fill") {
            Text("NexControl MIDI Hub")
                .font(.headline)
            Divider()

            Section("MIDI Hardware") {
                if nexControl.isMidiConnected {
                    Text("Active: \(nexControl.midiDeviceName)")
                    ForEach(nexControl.connectedDevices) { dev in
                        Text("• \(dev.displayName) [\(dev.tierLabel)]")
                            .font(.caption)
                    }
                } else {
                    Text("Device: None detected")
                }

                Button("Reload Custom Profiles") {
                    nexControl.reloadProfiles()
                }
            }

            Divider()

            Section("Knob Activity") {
                Text(nexControl.lastActivityText)
                if nexControl.totalTicks > 0 {
                    Text("Accumulated total: \(nexControl.totalTicks) ticks")
                }
            }

            Divider()

            Button(nexControl.isRunning ? "Pause MIDI Hub" : "Start MIDI Hub") {
                if nexControl.isRunning {
                    nexControl.stop()
                } else {
                    nexControl.start()
                }
            }

            Divider()

            Button("Quit MCNexus") {
                NSApplication.shared.terminate(nil)
            }
        }
        #endif
    }
}
