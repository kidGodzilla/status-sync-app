//
//  SettingsView.swift
//  status sync app
//
//  Created by James Futhey on 1/14/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @State private var serverURL: String
    @State private var thresholdSeconds: Int
    @State private var pollIntervalSeconds: Int
    @State private var myDisplayName: String
    @State private var myHandle: String
    @State private var myAvatarData: Data?
    @State private var saveFeedback: String?
    
    init(appState: AppState) {
        self.appState = appState
        _serverURL = State(initialValue: appState.settings.serverBaseURL)
        _thresholdSeconds = State(initialValue: appState.settings.presenceThresholdSeconds)
        _pollIntervalSeconds = State(initialValue: appState.settings.pollIntervalSeconds)
        _myDisplayName = State(initialValue: appState.settings.myDisplayName)
        _myHandle = State(initialValue: appState.settings.myHandle)
        _myAvatarData = State(initialValue: appState.settings.myAvatarData)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.title2)
                .fontWeight(.semibold)
            
            Group {
                Text("Server")
                    .font(.headline)
                TextField("Server Base URL", text: $serverURL)
            }
            
            Group {
                Text("Presence")
                    .font(.headline)
                Stepper(value: $thresholdSeconds, in: 30...600, step: 30) {
                    Text("Presence Threshold: \(thresholdSeconds) seconds")
                }
                Stepper(value: $pollIntervalSeconds, in: 10...60, step: 10) {
                    Text("Poll Interval: \(pollIntervalSeconds) seconds")
                }
            }
            
            Group {
                Text("Your Info")
                    .font(.headline)
                TextField("Your display name", text: $myDisplayName)
                TextField("Your handle (email or phone)", text: $myHandle)
                    .help("Used locally for iMessage/FaceTime shortcuts")
                
                HStack(spacing: 12) {
                    avatarPreview()
                    VStack(alignment: .leading, spacing: 6) {
                        Button("Choose Photo") { pickAvatar() }
                        Button("Clear Photo") { myAvatarData = nil }
                            .disabled(myAvatarData == nil)
                    }
                }
            }
            
            Spacer()
            
            if let saveFeedback {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(saveFeedback)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .font(.caption)
            }
            
            Button(action: {
                    var cleanedURL = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
                    if cleanedURL.hasSuffix("/") {
                        cleanedURL.removeLast()
                    }
                    
                    appState.storage.settings.serverBaseURL = cleanedURL
                appState.storage.settings.presenceThresholdSeconds = thresholdSeconds
                appState.storage.settings.pollIntervalSeconds = pollIntervalSeconds
                    appState.storage.settings.myDisplayName = myDisplayName
                    appState.storage.settings.myHandle = normalizeHandle(myHandle)
                appState.storage.settings.myAvatarData = myAvatarData
                appState.storage.save()
                appState.updateSettings()
                saveFeedback = "Saved"
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    saveFeedback = nil
                }
            }) {
                Text("Save")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(20)
        .frame(minWidth: 420, minHeight: 320)
    }
    
    @ViewBuilder
    private func avatarPreview() -> some View {
        if let data = myAvatarData, let nsImage = NSImage(data: data) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFill()
                .frame(width: 48, height: 48)
                .clipShape(Circle())
        } else {
            Text("👤")
                .font(.title2)
                .frame(width: 48, height: 48)
                .background(Circle().fill(Color.secondary.opacity(0.2)))
        }
    }
    
    private func pickAvatar() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic, .heif]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { resp in
            if resp == .OK, let url = panel.url, let data = try? Data(contentsOf: url) {
                myAvatarData = data
            }
        }
    }
}
