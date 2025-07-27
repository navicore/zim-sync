import SwiftUI
import ZimSyncCore

struct ZimSyncMenuView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundColor(.blue)
                Text("ZimSync")
                    .font(.headline)
                Spacer()
                Circle()
                    .fill(appState.isServerRunning ? .green : .red)
                    .frame(width: 8, height: 8)
            }
            
            Divider()
            
            // Server controls
            HStack {
                if appState.isServerRunning {
                    Button("Stop Server") {
                        Task {
                            await appState.stopServer()
                        }
                    }
                    .foregroundColor(.red)
                } else {
                    Button("Start Server") {
                        Task {
                            await appState.startServer()
                        }
                    }
                    .foregroundColor(.green)
                }
                
                Spacer()
                
                Text("Port: \(appState.serverPort)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Shared directory
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Shared Folder:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Change") {
                        appState.selectSharedDirectory()
                    }
                    .font(.caption)
                }
                
                Button(action: {
                    appState.openSharedDirectory()
                }) {
                    HStack {
                        Image(systemName: "folder")
                        Text(appState.sharedDirectory.lastPathComponent)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Image(systemName: "arrow.up.forward.app")
                            .font(.caption)
                    }
                }
                .buttonStyle(.borderless)
                .foregroundColor(.primary)
            }
            
            // Discovered devices
            if !appState.discoveredDevices.isEmpty {
                Divider()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Nearby Devices")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(appState.discoveredDevices) { device in
                        HStack {
                            Image(systemName: deviceIcon(for: device))
                                .foregroundColor(.blue)
                            Text(device.deviceInfo?.name ?? "Unknown Device")
                                .font(.caption)
                            Spacer()
                            Circle()
                                .fill(.green)
                                .frame(width: 6, height: 6)
                        }
                    }
                }
            }
            
            // Active transfers
            if !appState.activeTransfers.isEmpty {
                Divider()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Active Transfers")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(appState.activeTransfers) { transfer in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Image(systemName: transfer.direction == .sending ? "arrow.up" : "arrow.down")
                                    .foregroundColor(transfer.direction == .sending ? .orange : .blue)
                                Text(transfer.fileName)
                                    .font(.caption)
                                    .lineLimit(1)
                                Spacer()
                                Text(transfer.speed)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            ProgressView(value: transfer.progress)
                                .progressViewStyle(.linear)
                                .frame(height: 4)
                        }
                    }
                }
            }
            
            Divider()
            
            // Footer actions
            HStack {
                Button("Settings") {
                    if #available(macOS 14.0, *) {
                        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    } else {
                        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                    }
                }
                .font(.caption)
                
                Spacer()
                
                Button("Quit") {
                    Task {
                        await appState.stopServer()
                        NSApplication.shared.terminate(nil)
                    }
                }
                .font(.caption)
                .foregroundColor(.red)
            }
        }
        .padding(12)
        .frame(width: 280)
    }
    
    private func deviceIcon(for device: AppState.DiscoveredDevice) -> String {
        guard let platform = device.deviceInfo?.platform else {
            return "questionmark.circle"
        }
        
        switch platform {
        case .macOS:
            return "macpro.gen3"
        case .iOS:
            return "iphone"
        case .iPadOS:
            return "ipad"
        }
    }
}