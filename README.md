# Status Sync

A minimal macOS menubar application that shares your presence status (active/away) with trusted contacts using a simple Node.js relay server.

## Overview

Status Sync is a privacy-focused presence sharing tool that allows two people to see each other's availability status. It monitors your keyboard and mouse activity to determine if you're "active" or "away," then shares this information with contacts you've added.

## Features

- **Menubar-only interface** - Runs in the background with no Dock icon
- **Automatic presence detection** - Monitors keyboard and mouse activity to determine your status
- **Contact management** - Add contacts by their unique user ID, automatically sync profile information
- **Profile sync** - Display names, handles, and avatars are automatically synced from the server
- **iMessage/FaceTime integration** - Quickly launch messages or calls from the contact menu
- **First-time setup wizard** - Guides you through initial profile configuration
- **Start at login** - Optional automatic launch when you log in
- **Configurable settings** - Adjust presence threshold, poll interval, and server URL

## How It Works

### Presence Detection

The app monitors your system's input activity using `CGEventSource` to track when you last pressed a key or moved the mouse. If your last input was within the configured threshold (default: 120 seconds), your status is "active"; otherwise, it's "away."

### Architecture

The app consists of two components:

1. **macOS Client** (Swift/SwiftUI)
   - Monitors local activity and determines presence state
   - Periodically posts presence updates to the server
   - Polls the server for contact presence updates
   - Stores contacts and settings locally using `UserDefaults`

2. **Relay Server** (Node.js/Express)
   - In-memory storage of presence state and user profiles
   - Stateless design - server restarts clear state, clients recover on next poll
   - No authentication required - user IDs (UUIDs) serve as identifiers
   - Implicit consent model - knowing someone's user ID is sufficient to view their presence

### Data Flow

1. **Presence Updates**: Your app monitors activity and posts your current status to `/presence/update` every configured interval (default: 30 seconds)
2. **Presence Queries**: Your app polls `/presence/get` for each contact to retrieve their latest status
3. **Profile Sync**: When you add a contact, the app fetches their profile (display name, handle, avatar) from `/profile/get`
4. **Profile Updates**: Your profile is synced to the server via `/profile/update` when you save settings, and periodically to keep it up to date

### Adding Contacts

To add a contact, you need their unique user ID (a UUID). When you add a contact by ID:
- The app fetches their profile information from the server (display name, handle, avatar)
- The contact automatically appears in your menu with their display name and current status
- You can view their status, last update time, and launch iMessage/FaceTime conversations

## Installation

### Prerequisites

- macOS (built for macOS, requires appropriate entitlements for App Sandbox)
- Node.js (for the relay server)
- Xcode (for building the macOS app)

### Building the macOS App

1. Open `status sync app/status sync app.xcodeproj` in Xcode
2. Build and run (⌘R)

### Setting Up the Relay Server

1. Install dependencies:
   ```bash
   npm install
   ```

2. Set environment variables:
   ```bash
   export PORT=5000
   export SERVER_SECRET=your-long-random-secret-string
   ```

3. Start the server:
   ```bash
   npm start
   ```

The server defaults to port 5000 and requires a `SERVER_SECRET` environment variable for HMAC token signing (though tokens are optional in the current implementation).

**Note**: For production, run the server behind a TLS proxy (e.g., nginx) as the server itself uses plain HTTP.

## Configuration

### Client Settings

Open Settings from the menubar menu to configure:

- **Your Info**: Display name, handle (email/phone), and avatar photo
- **Server**: Base URL for the relay server (default: `https://statussync.jamesfuthey.com`)
- **Presence**: Threshold for "active" status (default: 120 seconds) and poll interval (default: 30 seconds)
- **General**: Start at login toggle

### Server Configuration

- `PORT`: Server port (default: 5000)
- `SERVER_SECRET`: Secret key for HMAC token signing (required)
- `CORS_ORIGIN`: Optional CORS origin for web clients

## Usage

1. **First Launch**: Complete the profile setup wizard with your display name and handle
2. **Add Contacts**: Click "Add Contact" in the menu and enter the user ID of someone you want to follow
3. **View Status**: Contacts appear in the menu with their current status and last update time
4. **Launch Conversations**: Click on a contact to open a context menu with options to message or call them
5. **Configure**: Open Settings to adjust preferences and update your profile

## Technical Details

### Presence States

- **Active**: Last input activity was within the threshold (default: 120 seconds)
- **Away**: Last input activity exceeded the threshold
- **Asleep**: (Future feature, not currently implemented)

### Data Storage

- **Local**: All settings and contacts are stored in `UserDefaults`
- **Server**: Presence state is stored in memory with a 3-minute TTL
- **Profiles**: User profiles (display name, handle, avatar) are stored in memory on the server

### Network Protocol

The app uses simple HTTP polling:
- POST requests to update presence
- POST requests to query presence
- GET requests to fetch profiles
- No WebSockets or persistent connections

### Privacy & Security

- **No authentication**: User IDs (UUIDs) are the only identifiers
- **Implicit consent**: Sharing your user ID implies consent to share presence
- **In-memory server**: No persistent storage on the server
- **Local storage**: All contact data is stored locally on your machine

## Development

### Project Structure

```
status-sync-app/
├── index.js                 # Node.js relay server
├── package.json             # Server dependencies
├── status sync app/         # macOS app source
│   └── status sync app/
│       ├── status_sync_appApp.swift  # App entry point
│       ├── AppState.swift            # Main state management
│       ├── MenuView.swift            # Menubar menu UI
│       ├── SettingsView.swift        # Settings window
│       ├── PresenceMonitor.swift     # Activity monitoring
│       ├── APIClient.swift           # Server communication
│       ├── StorageManager.swift      # Local persistence
│       └── ...
└── README.md                # This file
```

### Key Components

- **`PresenceMonitor`**: Monitors keyboard/mouse activity using CoreGraphics
- **`AppState`**: Central state management, coordinates timers and API calls
- **`APIClient`**: Handles all HTTP requests to the relay server
- **`StorageManager`**: Manages local persistence using `UserDefaults`
- **`MenuView`**: SwiftUI view for the menubar menu
- **`SettingsView`**: SwiftUI view for the settings window

## License

ISC

## Author

James Futhey
