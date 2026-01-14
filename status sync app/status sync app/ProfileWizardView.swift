//
//  ProfileWizardView.swift
//  status sync app
//
//  Created by James Futhey on 1/14/26.
//

import SwiftUI

struct ProfileWizardView: View {
    @ObservedObject var appState: AppState
    var onDone: (() -> Void)?
    @FocusState private var focusedField: Field?
    
    @State private var displayName: String
    @State private var handle: String
    private let wasProfileIncomplete: Bool
    
    enum Field { case name, handle }
    
    init(appState: AppState, onDone: (() -> Void)? = nil) {
        self.appState = appState
        self.onDone = onDone
        _displayName = State(initialValue: appState.settings.myDisplayName)
        _handle = State(initialValue: appState.settings.myHandle)
        self.wasProfileIncomplete = appState.settings.myDisplayName.isEmpty || appState.settings.myHandle.isEmpty
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Set up your profile")
                .font(.headline)
            
            TextField("Display name", text: $displayName)
                .focused($focusedField, equals: .name)
            TextField("Handle (email or phone)", text: $handle)
                .focused($focusedField, equals: .handle)
                .help("Used locally for iMessage/FaceTime shortcuts")
            
            Spacer()
            
            HStack {
                Spacer()
                Button("Save") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .disabled(displayName.isEmpty || handle.isEmpty)
            }
        }
        .padding(16)
        .frame(width: 360, height: 200)
        .onAppear { focusedField = .name }
    }
    
    private func save() {
        appState.storage.settings.myDisplayName = displayName
        appState.storage.settings.myHandle = normalizeHandle(handle)

        // Default to enabling "Start at Login" after initial setup completes.
        if wasProfileIncomplete && !appState.storage.settings.startAtLogin {
            appState.storage.settings.startAtLogin = true
            do {
                try LoginItemManager.shared.setEnabled(true)
            } catch {
                print("DEBUG: ProfileWizard setEnabled(startAtLogin=true) ERROR \(error)")
            }
        }

        appState.storage.save()
        appState.updateSettings()
        
        // Sync profile to server
        appState.syncMyProfileToServer()
        
        onDone?()
    }
    
    private func normalizeHandle(_ handle: String) -> String {
        let trimmed = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("@") {
            // Email: lowercase
            return trimmed.lowercased()
        } else {
            // Phone: keep + prefix, strip other non-digits
            let digits = trimmed.filter { $0.isNumber || $0 == "+" }
            return digits.hasPrefix("+") ? digits : "+" + digits.filter { $0.isNumber }
        }
    }
}
