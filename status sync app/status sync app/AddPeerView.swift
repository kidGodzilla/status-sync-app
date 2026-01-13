//
//  AddPeerView.swift
//  status sync app
//
//  Created by James Futhey on 1/14/26.
//

import SwiftUI
import Contacts

struct AddPeerView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var peerUserId: String = ""
    @State private var displayName: String = ""
    @State private var handle: String = ""
    @State private var searchText: String = ""
    @State private var contacts: [CNContact] = []
    @State private var selectedContact: CNContact?
    @State private var showUserIdInput = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add Peer")
                .font(.title2)
                .fontWeight(.semibold)
            
            if !showUserIdInput {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Enter contact details")
                        .font(.headline)
                    
                    TextField("Display Name", text: $displayName)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("Email or Phone", text: $handle)
                        .textFieldStyle(.roundedBorder)
                        .help("Used for iMessage/FaceTime shortcuts")
                    
                    Button(action: {
                        if !displayName.isEmpty && !handle.isEmpty {
                            showUserIdInput = true
                        }
                    }) {
                        Text("Next")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(displayName.isEmpty || handle.isEmpty)
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Enter their User ID")
                        .font(.headline)
                    
                    Text("Ask the person for their Status Sync User ID")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("User ID", text: $peerUserId)
                        .textFieldStyle(.roundedBorder)
                    
                    Button(action: {
                        if !peerUserId.isEmpty && !handle.isEmpty {
                            let peer = Peer(
                                peerUserId: peerUserId,
                                displayName: displayName,
                                handle: handle,
                                capabilityToken: nil,
                                lastKnownPresence: nil
                            )
                            appState.addPeer(peer)
                            dismiss()
                        }
                    }) {
                        Text("Add")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(peerUserId.isEmpty)
                }
            }
            
            Button(action: {
                dismiss()
            }) {
                Text("Cancel")
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .frame(width: 400)
    }
}
