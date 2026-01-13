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
    
    enum Field { case name, handle }
    
    init(appState: AppState, onDone: (() -> Void)? = nil) {
        self.appState = appState
        self.onDone = onDone
        _displayName = State(initialValue: appState.settings.myDisplayName)
        _handle = State(initialValue: appState.settings.myHandle)
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
        appState.storage.settings.myHandle = handle
        appState.storage.save()
        appState.updateSettings()
        onDone?()
    }
}
