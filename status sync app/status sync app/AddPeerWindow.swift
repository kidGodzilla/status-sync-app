//
//  AddPeerWindow.swift
//  status sync app
//
//  Created by James Futhey on 1/14/26.
//

import SwiftUI
import AppKit

/// Presents the AddPeerView in a separate floating panel so it doesn't disappear when the menu closes.
final class AddPeerWindowController {
    static let shared = AddPeerWindowController()
    
    private var window: NSPanel?
    
    func present(appState: AppState) {
        // Activate app first
        NSApp.activate(ignoringOtherApps: true)
        
        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            return
        }
        
        let content = AddPeerView(appState: appState) {
            self.window?.close()
            self.window = nil
        }
        
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 260),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = "Add Contact"
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = .canJoinAllSpaces
        panel.contentView = NSHostingView(rootView: content)
        panel.center()
        
        self.window = panel
        panel.makeKeyAndOrderFront(nil)
    }
}
