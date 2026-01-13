//
//  MenuView.swift
//  status sync app
//
//  Created by James Futhey on 1/14/26.
//

import SwiftUI
import AppKit

@ViewBuilder
func avatarView(text: String, avatarData: Data? = nil, size: CGFloat = 24) -> some View {
    if let data = avatarData, let nsImage = NSImage(data: data) {
        Image(nsImage: nsImage)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
    } else {
        let initials = initialsFrom(text)
        Text(initials.isEmpty ? "?" : initials)
            .font(.caption.weight(.bold))
            .foregroundColor(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(Color.accentColor.opacity(0.9)))
    }
}

func initialsFrom(_ text: String) -> String {
    let parts = text.split(separator: " ")
    if let first = parts.first?.first {
        if parts.count > 1, let second = parts.dropFirst().first?.first {
            return String([first, second]).uppercased()
        }
        return String(first).uppercased()
    }
    return "?"
}

struct MenuView: View {
    @ObservedObject var appState: AppState
    @State private var showAddPeerSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // My Status Section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    let myName = appState.settings.myDisplayName.isEmpty ? "You" : appState.settings.myDisplayName
                    avatarView(text: myName, avatarData: appState.settings.myAvatarData)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(myName)
                            .font(.headline)
                        HStack(spacing: 6) {
                            Circle()
                                .fill(statusColor(for: appState.presenceMonitor.currentState))
                                .frame(width: 8, height: 8)
                            Text(appState.presenceMonitor.currentState.rawValue.capitalized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
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
            
            if appState.profileNeedsSetup {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Complete your profile")
                        .font(.headline)
                        .padding(.horizontal, 12)
                    SettingsLink {
                        Label("Open Settings", systemImage: "gearshape")
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
                
                Divider()
            }
            
            // Contacts Section
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Contacts")
                        .font(.headline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    Spacer()
                    Button(action: {
                        NSApp.sendAction(#selector(NSMenu.cancelTracking), to: nil, from: nil)
                        AddPeerWindowController.shared.present(appState: appState)
                    }) {
                        Image(systemName: "plus")
                            .padding(6)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 12)
                }
                
                if appState.settings.peers.isEmpty {
                    Text("No contacts added")
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
            .simultaneousGesture(TapGesture().onEnded {
                NSApp.sendAction(#selector(NSMenu.cancelTracking), to: nil, from: nil)
                NSApp.activate(ignoringOtherApps: true)
            })
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
    
    private var displayLabel: String {
        if !peer.displayName.isEmpty { return peer.displayName }
        if !peer.handle.isEmpty { return peer.handle }
        return peer.peerUserId
    }
    
    private var subtitleLabel: String {
        if !peer.handle.isEmpty { return peer.handle }
        return peer.peerUserId
    }
    
    private func avatarInitials() -> String {
        let source = displayLabel
        let parts = source.split(separator: " ")
        if let first = parts.first?.first {
            if parts.count > 1, let second = parts.dropFirst().first?.first {
                return String([first, second]).uppercased()
            }
            return String(first).uppercased()
        }
        return "?"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                avatarView(text: displayLabel, avatarData: peer.avatarData)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayLabel)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(subtitleLabel)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
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
                    
                    Button(action: {
                        NSApp.sendAction(#selector(NSMenu.cancelTracking), to: nil, from: nil)
                        EditContactWindowController.shared.present(appState: appState, peer: peer)
                    }) {
                        Label("Edit Contact", systemImage: "pencil")
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
        let h = normalizeHandle(handle)
        guard !h.isEmpty else { return }
        if let url = URL(string: "sms:\(h)") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func openFaceTime(handle: String) {
        let h = normalizeHandle(handle)
        guard !h.isEmpty else { return }
        if let url = URL(string: "facetime://\(h)") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func openFaceTimeAudio(handle: String) {
        let h = normalizeHandle(handle)
        guard !h.isEmpty else { return }
        if let url = URL(string: "facetime-audio://\(h)") {
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
