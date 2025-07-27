import SwiftUI
import ZimSyncCore

@available(iOS 17.0, *)
public struct ZimSyncMainView: View {
    @StateObject private var appModel = ZimSyncAppModel()
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("ZimSync")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Fast file sync for audio production")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top)
                    
                    // Quick actions
                    VStack(spacing: 16) {
                        ActionCard(
                            icon: "square.and.arrow.up",
                            title: "Share from AUM",
                            description: "Use the share button in AUM to send files to your Mac",
                            color: .blue
                        ) {
                            // Show share instructions
                        }
                        
                        ActionCard(
                            icon: "macpro.gen3",
                            title: "Find Devices",
                            description: "Discover ZimSync servers on your network",
                            color: .green
                        ) {
                            Task {
                                await appModel.startDiscovery()
                            }
                        }
                        
                        ActionCard(
                            icon: "folder",
                            title: "Browse Files",
                            description: "View and manage your synced files",
                            color: .orange
                        ) {
                            // Open file browser
                        }
                    }
                    
                    // Discovered devices
                    if !appModel.discoveredServers.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Available Devices")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(appModel.discoveredServers) { server in
                                DeviceCard(server: server)
                            }
                        }
                    }
                    
                    // Recent transfers
                    if !appModel.recentTransfers.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recent Transfers")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(appModel.recentTransfers) { transfer in
                                TransferCard(transfer: transfer)
                            }
                        }
                    }
                    
                    // Tips
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Getting Started")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        TipCard(
                            icon: "1.circle.fill",
                            title: "Install ZimSync on your Mac",
                            description: "Download and run the ZimSync menu bar app"
                        )
                        
                        TipCard(
                            icon: "2.circle.fill",
                            title: "Connect to the same WiFi",
                            description: "Both devices need to be on the same network"
                        )
                        
                        TipCard(
                            icon: "3.circle.fill",
                            title: "Share from any app",
                            description: "Use the share button and select ZimSync"
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("ZimSync")
            .refreshable {
                await appModel.refresh()
            }
        }
        .onAppear {
            Task {
                await appModel.startDiscovery()
            }
        }
    }
}

struct ActionCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

struct DeviceCard: View {
    let server: ZimSyncClient.DiscoveredServer
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "macpro.gen3")
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(server.name)
                    .font(.headline)
                HStack {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                    Text("Available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("Local")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.green.opacity(0.1))
                    .foregroundColor(.green)
                    .cornerRadius(4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
}

struct TransferCard: View {
    let transfer: ZimSyncAppModel.RecentTransfer
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: transfer.direction == .sent ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .font(.title2)
                .foregroundColor(transfer.direction == .sent ? .blue : .green)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(transfer.fileName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("\(transfer.direction == .sent ? "Sent to" : "Received from") \(transfer.deviceName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(transfer.date, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if transfer.isSuccessful {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct TipCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

@available(iOS 17.0, *)
@MainActor
class ZimSyncAppModel: ObservableObject {
    @Published var discoveredServers: [ZimSyncClient.DiscoveredServer] = []
    @Published var recentTransfers: [RecentTransfer] = []
    
    private let client = ZimSyncClient()
    
    struct RecentTransfer: Identifiable {
        let id = UUID()
        let fileName: String
        let deviceName: String
        let direction: Direction
        let date: Date
        let isSuccessful: Bool
        
        enum Direction {
            case sent, received
        }
    }
    
    func startDiscovery() async {
        let discoveryStream = await client.startDiscovery()
        
        Task {
            for await server in discoveryStream {
                discoveredServers.append(server)
            }
        }
    }
    
    func refresh() async {
        // Refresh discovered devices
        discoveredServers.removeAll()
        await startDiscovery()
        
        // Load recent transfers (would come from persistence)
        loadRecentTransfers()
    }
    
    private func loadRecentTransfers() {
        // Mock data - in real app this would come from CoreData/etc
        recentTransfers = [
            RecentTransfer(
                fileName: "track_01.wav",
                deviceName: "Mac Studio",
                direction: .sent,
                date: Date().addingTimeInterval(-300), // 5 min ago
                isSuccessful: true
            ),
            RecentTransfer(
                fileName: "drum_loop.aiff",
                deviceName: "Mac Studio",
                direction: .sent,
                date: Date().addingTimeInterval(-1800), // 30 min ago
                isSuccessful: true
            )
        ]
    }
}