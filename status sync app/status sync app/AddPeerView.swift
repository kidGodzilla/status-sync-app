//
//  AddPeerView.swift
//  status sync app
//
//  Created by James Futhey on 1/14/26.
//

import SwiftUI

struct AddPeerView: View {
    @ObservedObject var appState: AppState
    var onDone: (() -> Void)? = nil
    @FocusState private var focusedField: Field?
    
    @State private var peerUserId: String = ""
    
    enum Field {
        case userId
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Add Contact")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Enter their User ID (shared out-of-band)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("User ID", text: $peerUserId)
                    .focused($focusedField, equals: .userId)
                
                Button("Add") {
                    addPeer()
                }
                .buttonStyle(.borderedProminent)
                .disabled(peerUserId.isEmpty)
                .frame(maxWidth: .infinity)
            }
            
            Button("Cancel") {
                onDone?()
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .frame(width: 280)
        .onAppear {
            focusedField = .userId
        }
    }
    
    private func addPeer() {
        guard !peerUserId.isEmpty else { return }
        
        // Create peer with placeholder - profile will be fetched from server
        let peer = Peer(
            peerUserId: peerUserId,
            displayName: "Contact",
            handle: "",
            avatarData: nil,
            capabilityToken: nil,
            lastKnownPresence: nil
        )
        appState.addPeer(peer)
        onDone?()
    }
}
