import SwiftUI
import ZimSyncCore

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var autoStartServer = true
    @State private var enableNotifications = true
    @State private var showTransferProgress = true
    
    var body: some View {
        TabView {
            GeneralSettingsView()
                .environmentObject(appState)
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            NetworkSettingsView()
                .environmentObject(appState)
                .tabItem {
                    Label("Network", systemImage: "network")
                }
            
            AdvancedSettingsView()
                .environmentObject(appState)
                .tabItem {
                    Label("Advanced", systemImage: "slider.horizontal.3")
                }
        }
        .frame(width: 500, height: 400)
    }
}

struct GeneralSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var autoStartServer = true
    @State private var enableNotifications = true
    @State private var launchAtLogin = false
    
    var body: some View {
        Form {
            Section("Audio Sync Preferences") {
                Toggle("Auto-start server on launch", isOn: $autoStartServer)
                Toggle("Show transfer notifications", isOn: $enableNotifications)
                Toggle("Launch at login", isOn: $launchAtLogin)
            }
            
            Section("Shared Directory") {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Current folder:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(appState.sharedDirectory.path)
                            .truncationMode(.middle)
                    }
                    
                    Spacer()
                    
                    Button("Choose...") {
                        appState.selectSharedDirectory()
                    }
                }
                
                HStack {
                    Button("Open in Finder") {
                        appState.openSharedDirectory()
                    }
                    
                    Spacer()
                    
                    Button("Reset to Default") {
                        let musicDir = FileManager.default.urls(for: .musicDirectory, in: .userDomainMask).first!
                        appState.sharedDirectory = musicDir.appendingPathComponent("ZimSync")
                    }
                }
            }
            
            Section("Audio Workflow") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ZimSync is optimized for audio production workflows:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Smart compression for audio files")
                                .font(.caption)
                        }
                        
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Fast local network transfers")
                                .font(.caption)
                        }
                        
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Automatic device discovery")
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .padding()
    }
}

struct NetworkSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var customPort: String = "8080"
    
    var body: some View {
        Form {
            Section("Network Configuration") {
                HStack {
                    Text("Port:")
                    TextField("Port", text: $customPort)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .onChange(of: customPort) { _, newValue in
                            if let port = UInt16(newValue), port > 1024 {
                                appState.serverPort = port
                            }
                        }
                    Text("(1025-65535)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Service Discovery:")
                    Text("Uses Bonjour (_zimsync._udp.local)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Connection Status") {
                HStack {
                    Circle()
                        .fill(appState.isServerRunning ? .green : .red)
                        .frame(width: 12, height: 12)
                    Text(appState.isServerRunning ? "Server Running" : "Server Stopped")
                    
                    Spacer()
                    
                    if appState.isServerRunning {
                        Text("Port \(appState.serverPort)")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(.green.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                
                if !appState.discoveredDevices.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Discovered Devices:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ForEach(appState.discoveredDevices) { device in
                            HStack {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                    .foregroundColor(.blue)
                                Text(device.deviceInfo?.name ?? "Unknown")
                                Spacer()
                                Text(device.deviceInfo?.platform.rawValue ?? "")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .onAppear {
            customPort = String(appState.serverPort)
        }
    }
}

struct AdvancedSettingsView: View {
    @State private var enableCompression = true
    @State private var chunkSize = 32
    @State private var maxConcurrentTransfers = 3
    @State private var enableLogging = false
    
    var body: some View {
        Form {
            Section("Transfer Optimization") {
                Toggle("Enable compression", isOn: $enableCompression)
                
                HStack {
                    Text("Chunk size:")
                    Picker("Chunk Size", selection: $chunkSize) {
                        Text("16 KB").tag(16)
                        Text("32 KB").tag(32)
                        Text("64 KB").tag(64)
                        Text("128 KB").tag(128)
                    }
                    .pickerStyle(.menu)
                }
                
                HStack {
                    Text("Max concurrent transfers:")
                    Stepper("\(maxConcurrentTransfers)", value: $maxConcurrentTransfers, in: 1...10)
                }
            }
            
            Section("Audio Processing") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Compressed formats (no recompression):")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("MP3, M4A, AAC, OGG, OPUS, FLAC")
                        .font(.caption)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Uncompressed formats (will compress):")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("WAV, AIFF, PCM")
                        .font(.caption)
                }
            }
            
            Section("Debugging") {
                Toggle("Enable debug logging", isOn: $enableLogging)
                
                if enableLogging {
                    HStack {
                        Button("Open Log Folder") {
                            // Open ~/Library/Logs/ZimSync
                            let logsDir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
                                .appendingPathComponent("Logs")
                                .appendingPathComponent("ZimSync")
                            NSWorkspace.shared.open(logsDir)
                        }
                        
                        Spacer()
                        
                        Button("Clear Logs") {
                            // Clear log files
                        }
                        .foregroundColor(.red)
                    }
                }
            }
        }
        .padding()
    }
}