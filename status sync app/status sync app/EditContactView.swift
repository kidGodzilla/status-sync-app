//
//  EditContactView.swift
//  status sync app
//
//  Created by James Futhey on 1/14/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct EditContactView: View {
    @ObservedObject var appState: AppState
    let peer: Peer
    var onDone: (() -> Void)?
    @FocusState private var focusedField: Field?
    
    @State private var displayName: String
    @State private var handle: String
    @State private var avatarData: Data?
    
    enum Field { case name, handle }
    
    init(appState: AppState, peer: Peer, onDone: (() -> Void)? = nil) {
        self.appState = appState
        self.peer = peer
        self.onDone = onDone
        _displayName = State(initialValue: peer.displayName)
        _handle = State(initialValue: peer.handle)
        _avatarData = State(initialValue: peer.avatarData)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Edit Contact")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                TextField("Display name", text: $displayName)
                    .focused($focusedField, equals: .name)
                
                TextField("Handle (email or phone)", text: $handle)
                    .focused($focusedField, equals: .handle)
            }
            
            HStack(spacing: 12) {
                avatarPreview()
                VStack(alignment: .leading, spacing: 8) {
                    Button("Choose Photo") { pickAvatar() }
                        .controlSize(.small)
                    Button("Clear Photo") { avatarData = nil }
                        .controlSize(.small)
                        .disabled(avatarData == nil)
                }
            }
            
            HStack {
                Button("Cancel") {
                    onDone?()
                }
                
                Spacer()
                
                Button("Save") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .disabled(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 380)
        .onAppear { focusedField = .name }
    }
    
    private func save() {
        var updated = peer
        updated.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.handle = normalizeHandle(handle)
        updated.avatarData = avatarData
        appState.updatePeer(updated)
        onDone?()
    }
    
    @ViewBuilder
    private func avatarPreview() -> some View {
        if let data = avatarData, let nsImage = NSImage(data: data) {
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
                // Compress the image before storing
                avatarData = compressAvatar(data) ?? data
            }
        }
    }
}
