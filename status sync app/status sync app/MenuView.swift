//
//  MenuView.swift
//  status sync app
//
//  Created by James Futhey on 1/14/26.
//

import SwiftUI
import AppKit
import Combine

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
    @Environment(\.openSettings) private var openSettings
    @State private var isHoveringMyIdRow = false
    @State private var isHoveringSettingsRow = false
    @State private var isHoveringQuitRow = false
    @State private var didCopyMyId = false
    
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
                .onTapGesture(count: 2) {
                    openSettingsAndBringToFront()
                }
                .padding(.horizontal, 12)
                
                HStack {
                    Text("ID: \(appState.settings.myUserId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Button(action: {
                        copyMyUserIdToClipboard()
                    }) {
                        ZStack {
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .opacity(didCopyMyId ? 0 : 1)
                            Image(systemName: "checkmark")
                                .font(.caption)
                                .foregroundColor(.green)
                                .opacity(didCopyMyId ? 1 : 0)
                        }
                        .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.plain)
                    .offset(x: 2)
                }
                .contentShape(Rectangle())
                .onTapGesture { copyMyUserIdToClipboard() }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(isHoveringMyIdRow ? hoverBackground : Color.clear)
                .cornerRadius(8)
                .padding(.horizontal, 6)
                .overlay(alignment: .trailing) {
                    if didCopyMyId {
                        Text("Copied")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(nsColor: NSColor.windowBackgroundColor).opacity(0.9))
                            .cornerRadius(4)
                            .padding(.trailing, 12 + 18 + 8) // row inner right + icon width + gap
                            .transition(.opacity)
                    }
                }
                .onHover { hovering in
                    isHoveringMyIdRow = hovering
                }
                
                if !appState.isOnline {
                    Text("Offline")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 12)
                }
            }
            .padding(.vertical, 8)
            
            Divider()
            
            if appState.profileNeedsSetup {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Complete your profile")
                        .font(.headline)
                        .padding(.horizontal, 12)
                    Button(action: { openSettingsAndBringToFront() }) {
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
                        .padding(.leading, 12)
                        .padding(.vertical, 6)
                    Spacer()
                    Button(action: {
                        collapseMenu()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            AddPeerWindowController.shared.present(appState: appState)
                        }
                    }) {
                        Image(systemName: "plus")
                            .padding(6)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 11)
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
            Button(action: { openSettingsAndBringToFront() }) {
                Label("Settings…", systemImage: "gearshape")
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .background(isHoveringSettingsRow ? hoverBackground : Color.clear)
            .cornerRadius(8)
            .padding(.horizontal, 6)
            .padding(.top, 4)
            .onHover { hovering in
                isHoveringSettingsRow = hovering
            }
            
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Label("Quit", systemImage: "power")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isHoveringQuitRow ? hoverBackground : Color.clear)
            .cornerRadius(8)
            .padding(.horizontal, 6)
            .padding(.bottom, 6)
            .onHover { hovering in
                isHoveringQuitRow = hovering
            }
        }
        .frame(width: 280)
    }
    
    private var hoverBackground: Color {
        Color(nsColor: NSColor.selectedContentBackgroundColor).opacity(0.35)
    }
    
    private func collapseMenu() {
        // MenuBarExtra(.window) doesn't reliably respond to NSMenu.cancelTracking.
        // We dismiss by ordering out the status-level window on the next runloop tick.
        DispatchQueue.main.async {
            NSApp.sendAction(#selector(NSMenu.cancelTracking), to: nil, from: nil)

            let statusBarLevel = NSWindow.Level.statusBar.rawValue
            for window in NSApplication.shared.windows where window.isVisible {
                if window.level.rawValue >= statusBarLevel {
                    window.orderOut(nil)
                    window.performClose(nil)
                }
            }

            NSApp.keyWindow?.orderOut(nil)
            NSApp.keyWindow?.performClose(nil)
        }
    }
    
    private func copyMyUserIdToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(appState.settings.myUserId, forType: .string)
        
        didCopyMyId = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            didCopyMyId = false
        }
    }
    
    private func openSettingsAndBringToFront() {
        collapseMenu()
        NSApp.activate(ignoringOtherApps: true)
        
        // Let the menu collapse first, then open Settings.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            openSettings()
            
            // Ensure the Settings window is brought to the front (it can sometimes appear behind other windows).
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                for window in NSApplication.shared.windows {
                    if window.title == "Settings" || window.title.contains("Settings") || window.title.contains("Preferences") {
                        window.makeKeyAndOrderFront(nil)
                        window.orderFrontRegardless()
                    }
                }
            }
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
    @State private var isHovering = false
    
    private func formatTimestamp(_ timestamp: Int64) -> String {
        // Important: this UI is not re-rendered every second (poll interval is ~30s),
        // so we intentionally avoid displaying second-level granularity like "2s ago".
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let delta = max(0, Int(Date().timeIntervalSince(date)))

        if delta < 60 { return "<1m ago" }
        if delta < 3600 { return "\(delta / 60)m ago" }
        if delta < 86400 { return "\(delta / 3600)h ago" }
        return "\(delta / 86400)d ago"
    }

    private func formatLocalTime(_ timestamp: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }

    // Helper to bridge NSMenuItem actions to Swift closures.
    final class MenuActionHandler: NSObject {
        private let action: () -> Void
        init(_ action: @escaping () -> Void) { self.action = action }
        @objc func performAction(_ sender: Any?) { action() }
    }

    private func showContactMenu() {
        let menu = NSMenu()

        var handlers: [MenuActionHandler] = []
        func addItem(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) {
            let item = NSMenuItem(title: title, action: #selector(MenuActionHandler.performAction(_:)), keyEquivalent: "")
            let h = MenuActionHandler(action)
            item.target = h
            if let systemImage, let img = NSImage(systemSymbolName: systemImage, accessibilityDescription: nil) {
                item.image = img
            }
            handlers.append(h)
            menu.addItem(item)
        }

        addItem("Message", systemImage: "message") { openMessage(handle: peer.handle) }
        addItem("FaceTime", systemImage: "video") { openFaceTime(handle: peer.handle) }
        addItem("FaceTime Audio", systemImage: "phone") { openFaceTimeAudio(handle: peer.handle) }
        menu.addItem(.separator())
        addItem("Edit Contact", systemImage: "pencil") {
            collapseMenuThen {
                EditContactWindowController.shared.present(appState: appState, peer: peer)
            }
        }
        menu.addItem(.separator())
        addItem("Remove", systemImage: "trash") {
            collapseMenuThen {
                appState.removePeer(peer.peerUserId)
            }
        }

        // Keep handlers alive for the duration of the menu.
        objc_setAssociatedObject(menu, Unmanaged.passUnretained(menu).toOpaque(), handlers, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        let p = NSEvent.mouseLocation
        menu.popUp(positioning: nil, at: p, in: nil)
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

                    if let presence = peer.lastKnownPresence {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(statusColor(for: presence.state))
                                .frame(width: 6, height: 6)
                            Text("\(presence.state.rawValue.capitalized) \(formatTimestamp(presence.timestamp))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Unknown")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Affordance stays visible; clicking it opens the same menu as clicking the row.
                Button(action: { showContactMenu() }) {
                    Image(systemName: "ellipsis.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isHovering ? Color(nsColor: NSColor.selectedContentBackgroundColor).opacity(0.35) : Color.clear)
            .cornerRadius(8)
            .padding(.horizontal, 6)
        }
        .contentShape(Rectangle())
        .onTapGesture { showContactMenu() }
        .onHover { hovering in
            isHovering = hovering
        }
        .help(peer.lastKnownPresence != nil ? "Local time: \(formatLocalTime(peer.lastKnownPresence!.timestamp))" : "")
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
        collapseMenuThen {
            if let url = URL(string: "sms:\(h)") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    private func openFaceTime(handle: String) {
        let h = normalizeHandle(handle)
        guard !h.isEmpty else { return }
        collapseMenuThen {
            if let url = URL(string: "facetime://\(h)") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    private func openFaceTimeAudio(handle: String) {
        let h = normalizeHandle(handle)
        guard !h.isEmpty else { return }
        collapseMenuThen {
            if let url = URL(string: "facetime-audio://\(h)") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    private func collapseMenuThen(_ action: @escaping () -> Void) {
        DispatchQueue.main.async {
            // Dismiss the MenuBarExtra window before launching external apps / panels.
            let statusBarLevel = NSWindow.Level.statusBar.rawValue
            for window in NSApplication.shared.windows where window.isVisible {
                if window.level.rawValue >= statusBarLevel {
                    window.orderOut(nil)
                    window.performClose(nil)
                }
            }
            NSApp.sendAction(#selector(NSMenu.cancelTracking), to: nil, from: nil)
            NSApp.keyWindow?.orderOut(nil)
            NSApp.keyWindow?.performClose(nil)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { action() }
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
                    NSApp.keyWindow?.orderOut(nil)
                    Task {
                        await appState.respondToRequest(request, decision: "allow")
                    }
                }) {
                    Text("Allow")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                
                Button(action: {
                    NSApp.keyWindow?.orderOut(nil)
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
