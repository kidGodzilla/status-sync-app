//
//  ProfileWizardWindow.swift
//  status sync app
//
//  Created by James Futhey on 1/14/26.
//

import SwiftUI
import AppKit

/// Presents a small floating window to collect profile info on first launch.
final class ProfileWizardWindowController {
    static let shared = ProfileWizardWindowController()
    private var window: NSPanel?
    
    func present(appState: AppState) {
        // Activate app first
        NSApp.activate(ignoringOtherApps: true)
        
        // If already open, focus it.
        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            return
        }
        
        let content = ProfileWizardView(appState: appState) { [weak self] in
            self?.window?.close()
            self?.window = nil
        }
        
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 200),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = "Profile Setup"
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
