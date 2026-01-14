//
//  status_sync_appApp.swift
//  status sync app
//
//  Created by James Futhey on 1/14/26.
//

import SwiftUI
import AppKit

@main
struct status_sync_appApp: App {
    @StateObject private var storage = StorageManager()
    @StateObject private var appState: AppState
    
    init() {
        let storage = StorageManager()
        let appState = AppState(storage: storage)
        _storage = StateObject(wrappedValue: storage)
        _appState = StateObject(wrappedValue: appState)
        
        // Hide Dock icon - this is a menubar-only app
        NSApplication.shared.setActivationPolicy(.accessory)
        
        // Show profile wizard on launch if needed
        DispatchQueue.main.async {
            if appState.profileNeedsSetup {
                ProfileWizardWindowController.shared.present(appState: appState)
            }
        }
    }
    
    var body: some Scene {
        MenuBarExtra("Status Sync", systemImage: "circle.fill") {
            MenuView(appState: appState)
        }
        .menuBarExtraStyle(.window)
        
        Settings {
            SettingsView(appState: appState)
        }
    }
}
