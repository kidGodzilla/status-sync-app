//
//  MenuView.swift
//  status sync app
//
//  Created by James Futhey on 1/14/26.
//

import SwiftUI
import AppKit

struct MenuView: View {
    @ObservedObject var appState: AppState
    @State private var showAddPeerSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // My Status Section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Status: \(appState.presenceMonitor.currentState.rawValue.capitalized)")
                        .font(.headline)
                    Circle()
                        .fill(statusColor(for: appState.presenceMonitor.currentState))
                        .frame(width: 8, height: 8)
                }
                
                HStack {
                    Text("ID: \(appState.settings.myUserId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(appState.settings.myUserId, forType: .string)
                    }) {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
                
                if !appState.isOnline {
                    Text("Offline")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            Divider()
            
            // Peers Section
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Peers")
                        .font(.headline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    Spacer()
                    Button(action: {
                        showAddPeerSheet = true
                    }) {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 12)
                }
                
                if appState.settings.peers.isEmpty {
                    Text("No peers added")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                } else {
                    ForEach(appState.settings.peers) { peer in
                        PeerRow(peer: peer, appState: appState)
                    }
                }
            }
            .padding(.vertical, 4)
            
            Divider()
            
            // Incoming Requests
            if !appState.incomingRequests.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Requests")
                        .font(.headline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    
                    ForEach(appState.incomingRequests) { request in
                        RequestRow(request: request, appState: appState)
                    }
                }
                .padding(.vertical, 4)
                
                Divider()
            }
            
            // Settings and Quit
            SettingsLink {
                Label("Settings…", systemImage: "gearshape")
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Label("Quit", systemImage: "power")
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .frame(width: 280)
        .sheet(isPresented: $showAddPeerSheet) {
            AddPeerView(appState: appState)
        }
    }
    
    private func statusColor(for state: PresenceState) -> Color {
        switch state {
        case .active: return .green
        case .away: return .orange
        case .asleep: return .blue
        }
    }
}

struct PeerRow: View {
    let peer: Peer
    @ObservedObject var appState: AppState
    @State private var showActions = false
    
    private func formatTimestamp(_ timestamp: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(peer.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if let presence = peer.lastKnownPresence {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(statusColor(for: presence.state))
                                    .frame(width: 6, height: 6)
                                Text(presence.state.rawValue.capitalized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Text(formatTimestamp(presence.timestamp))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Unknown")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Menu {
                    Button(action: {
                        openMessage(handle: peer.handle)
                    }) {
                        Label("Message", systemImage: "message")
                    }
                    
                    Button(action: {
                        openFaceTime(handle: peer.handle)
                    }) {
                        Label("FaceTime", systemImage: "video")
                    }
                    
                    Button(action: {
                        openFaceTimeAudio(handle: peer.handle)
                    }) {
                        Label("FaceTime Audio", systemImage: "phone")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive, action: {
                        appState.removePeer(peer.peerUserId)
                    }) {
                        Label("Remove", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }
    
    private func statusColor(for state: PresenceState) -> Color {
        switch state {
        case .active: return .green
        case .away: return .orange
        case .asleep: return .blue
        }
    }
    
    private func openMessage(handle: String) {
        if let url = URL(string: "sms:\(handle)") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func openFaceTime(handle: String) {
        if let url = URL(string: "facetime://\(handle)") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func openFaceTimeAudio(handle: String) {
        if let url = URL(string: "facetime-audio://\(handle)") {
            NSWorkspace.shared.open(url)
        }
    }
}

struct RequestRow: View {
    let request: PresenceRequest
    @ObservedObject var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Request from: \(request.from)")
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.top, 6)
            
            HStack {
                Button(action: {
                    Task {
                        await appState.respondToRequest(request, decision: "allow")
                    }
                }) {
                    Text("Allow")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                
                Button(action: {
                    Task {
                        await appState.respondToRequest(request, decision: "deny")
                    }
                }) {
                    Text("Deny")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
        }
    }
}
