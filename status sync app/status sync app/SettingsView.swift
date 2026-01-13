//
//  SettingsView.swift
//  status sync app
//
//  Created by James Futhey on 1/14/26.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @State private var serverURL: String
    @State private var thresholdSeconds: Int
    @State private var pollIntervalSeconds: Int
    
    init(appState: AppState) {
        self.appState = appState
        _serverURL = State(initialValue: appState.settings.serverBaseURL)
        _thresholdSeconds = State(initialValue: appState.settings.presenceThresholdSeconds)
        _pollIntervalSeconds = State(initialValue: appState.settings.pollIntervalSeconds)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Settings")
                .font(.title2)
                .fontWeight(.semibold)
            
            Form {
                TextField("Server Base URL", text: $serverURL)
                
                Stepper(value: $thresholdSeconds, in: 30...600, step: 30) {
                    Text("Presence Threshold: \(thresholdSeconds) seconds")
                }
                
                Stepper(value: $pollIntervalSeconds, in: 10...60, step: 10) {
                    Text("Poll Interval: \(pollIntervalSeconds) seconds")
                }
            }
            .formStyle(.grouped)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Privacy")
                    .font(.headline)
                Text("This app determines whether your Mac is in use based solely on time since last keyboard/mouse input. It does not record keystrokes, screen contents, app usage, or messages. Contacts access is used only to select a name/handle for quick Message/FaceTime shortcuts and is never uploaded.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            
            Button(action: {
                appState.storage.settings.serverBaseURL = serverURL
                appState.storage.settings.presenceThresholdSeconds = thresholdSeconds
                appState.storage.settings.pollIntervalSeconds = pollIntervalSeconds
                appState.storage.save()
                appState.updateSettings()
            }) {
                Text("Save")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(width: 500, height: 500)
    }
}
