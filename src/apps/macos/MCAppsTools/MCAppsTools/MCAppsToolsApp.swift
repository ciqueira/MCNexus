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
    #if ENABLE_NEXCONTROL
    private var activity: NSObjectProtocol?
    #endif

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if ENABLE_NEXCONTROL
        // Prevent App Nap while MIDI hub is running
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .latencyCritical],
            reason: "NexControl MIDI Streaming Hub"
        )
        NexControlBridge.shared.start()
        #endif
    }

    func applicationWillTerminate(_ notification: Notification) {
        #if ENABLE_NEXCONTROL
        NexControlBridge.shared.stop()
        if let act = activity {
            ProcessInfo.processInfo.endActivity(act)
        }
        #endif
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        #if ENABLE_NEXCONTROL
        false // Keep app alive in menu bar
        #else
        true
        #endif
    }
}
#endif

@main
struct MCAppToolsApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #if ENABLE_NEXCONTROL
    @StateObject private var nexControl = NexControlBridge.shared
    #endif
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
                .handlesExternalEvents(preferring: Set(arrayLiteral: "*"), allowing: Set(arrayLiteral: "*"))
        }
        .windowResizability(.contentSize)
        .handlesExternalEvents(matching: Set(arrayLiteral: "*"))

        #if os(macOS) && ENABLE_NEXCONTROL
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
