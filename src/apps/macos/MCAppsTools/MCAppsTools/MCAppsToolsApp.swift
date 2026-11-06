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

            Section("IPC Server") {
                Text(nexControl.isRunning ? "Status: Active (UDS Socket)" : "Status: Disabled")
            }

            Divider()

            Section("MIDI Hardware") {
                if nexControl.isMidiConnected {
                    Text("Device: \(nexControl.midiDeviceName)")
                } else {
                    Text("Device: None detected")
                }
            }

            Divider()

            Section("OFX Plugin (DaVinci Resolve)") {
                if nexControl.isClientConnected {
                    Text("Plugin: \(nexControl.clientPluginName)")
                } else {
                    Text("Plugin: Disconnected")
                }
            }

            Divider()

            Section("Active Node") {
                if nexControl.activeNodeId > 0 {
                    Text("Focused Node: ID \(nexControl.activeNodeId)")
                } else {
                    Text("Focused Node: None")
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
