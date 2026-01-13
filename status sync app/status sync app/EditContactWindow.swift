//
//  EditContactWindow.swift
//  status sync app
//
//  Created by James Futhey on 1/14/26.
//

import SwiftUI
import AppKit

final class EditContactWindowController {
    static let shared = EditContactWindowController()
    private var window: NSPanel?
    
    func present(appState: AppState, peer: Peer) {
        // Activate app first
        NSApp.activate(ignoringOtherApps: true)
        
        // Close any existing edit window
        window?.close()
        window = nil
        
        let content = EditContactView(appState: appState, peer: peer) { [weak self] in
            self?.window?.close()
            self?.window = nil
        }
        
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 280),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = "Edit Contact"
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
