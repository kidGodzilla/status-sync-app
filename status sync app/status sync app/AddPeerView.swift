//
//  AddPeerView.swift
//  status sync app
//
//  Created by James Futhey on 1/14/26.
//

import SwiftUI

struct AddPeerView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    
    @State private var peerUserId: String = ""
    @State private var displayName: String = ""
    @State private var handle: String = ""
    
    enum Field {
        case displayName, handle, userId
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Add Peer")
                .font(.title2)
                .fontWeight(.semibold)
            
            Form {
                TextField("Display Name", text: $displayName)
                    .focused($focusedField, equals: .displayName)
                
                TextField("Email or Phone", text: $handle)
                    .focused($focusedField, equals: .handle)
                    .help("Used for iMessage/FaceTime shortcuts")
                
                TextField("User ID", text: $peerUserId)
                    .focused($focusedField, equals: .userId)
                    .help("Ask the person for their Status Sync User ID")
            }
            .formStyle(.grouped)
            .frame(width: 400)
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Add") {
                    addPeer()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
        }
        .padding()
        .onAppear {
            focusedField = .displayName
        }
    }
    
    private var isValid: Bool {
        !displayName.isEmpty && !handle.isEmpty && !peerUserId.isEmpty
    }
    
    private func addPeer() {
        guard isValid else { return }
        
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
}
