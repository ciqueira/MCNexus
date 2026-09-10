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
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
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
                // Backlog item 4 — every `open mcnexus://...` activation
                // (updates/activate/deactivate/refresh alike, they all share
                // one onOpenURL in ContentView) otherwise spawns a NEW
                // WindowGroup scene instance instead of reusing the window
                // already open: plain WindowGroup treats each external-event
                // activation as a request for a new window of the group.
                // There is no "New Window" command anywhere in this app's
                // menu, so a second window was never an intended outcome —
                // it only ever showed up once someone opened the same link
                // twice. preferring/allowing "*" routes every external
                // event, whatever the scheme host, into whichever window
                // instance already claims it, instead of minting another.
                .handlesExternalEvents(preferring: Set(arrayLiteral: "*"), allowing: Set(arrayLiteral: "*"))
        }
        .windowResizability(.contentSize)
        .handlesExternalEvents(matching: Set(arrayLiteral: "*"))
    }
}
