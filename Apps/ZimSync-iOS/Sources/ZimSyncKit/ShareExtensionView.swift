import SwiftUI
import ZimSyncCore
import UniformTypeIdentifiers

@available(iOS 17.0, *)
public struct ShareExtensionView: View {
    @StateObject private var shareModel = ShareExtensionModel()
    @Environment(\.dismiss) private var dismiss
    
    public let sharedItems: [Any]
    
    public init(sharedItems: [Any]) {
        self.sharedItems = sharedItems
    }
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                    
                    Text("ZimSync")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Share to your Mac instantly")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Files to share
                if !shareModel.filesToShare.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Files to Share")
                            .font(.headline)
                        
                        ForEach(shareModel.filesToShare, id: \.url) { file in
                            HStack {
                                Image(systemName: iconForFile(file.url))
                                    .foregroundColor(colorForFile(file.url))
                                
                                VStack(alignment: .leading) {
                                    Text(file.url.lastPathComponent)
                                        .font(.subheadline)
                                    Text(formatFileSize(file.size))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                }
                
                // Discovered servers
                VStack(alignment: .leading, spacing: 8) {
                    Text("Available Devices")
                        .font(.headline)
                    
                    if shareModel.discoveredServers.isEmpty {
                        if shareModel.isScanning {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Looking for devices...")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        } else {
                            VStack(spacing: 8) {
                                Image(systemName: "wifi.slash")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                                Text("No ZimSync devices found")
                                    .font(.subheadline)
                                Text("Make sure ZimSync is running on your Mac")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        }
                    } else {
                        ForEach(shareModel.discoveredServers) { server in
                            Button(action: {
                                shareModel.selectedServer = server
                                Task {
                                    await shareModel.sendFiles()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "macpro.gen3")
                                        .foregroundColor(.blue)
                                    
                                    VStack(alignment: .leading) {
                                        Text(server.name)
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                        Text("Available")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "arrow.right")
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(.systemBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(.systemGray4), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                Spacer()
                
                // Transfer progress
                if shareModel.isTransferring {
                    VStack(spacing: 8) {
                        ProgressView(value: shareModel.transferProgress)
                            .progressViewStyle(.linear)
                        
                        HStack {
                            Text(shareModel.transferStatus)
                                .font(.caption)
                            Spacer()
                            Text("\(Int(shareModel.transferProgress * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
            .padding()
            .navigationTitle("Share to ZimSync")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                }
            )
        }
        .onAppear {
            shareModel.processSharedItems(sharedItems)
            Task {
                await shareModel.startDiscovery()
            }
        }
        .onDisappear {
            Task {
                await shareModel.stopDiscovery()
            }
        }
    }
    
    private func iconForFile(_ url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        
        switch ext {
        case "wav", "aiff", "aif":
            return "waveform"
        case "mp3", "m4a", "aac":
            return "music.note"
        case "flac", "alac":
            return "music.note.list"
        default:
            return "doc"
        }
    }
    
    private func colorForFile(_ url: URL) -> Color {
        let ext = url.pathExtension.lowercased()
        
        switch ext {
        case "wav", "aiff", "aif":
            return .blue
        case "mp3", "m4a", "aac":
            return .green
        case "flac", "alac":
            return .purple
        default:
            return .gray
        }
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

@available(iOS 17.0, *)
@MainActor
class ShareExtensionModel: ObservableObject {
    @Published var filesToShare: [FileToShare] = []
    @Published var discoveredServers: [ZimSyncClient.DiscoveredServer] = []
    @Published var selectedServer: ZimSyncClient.DiscoveredServer?
    @Published var isScanning = false
    @Published var isTransferring = false
    @Published var transferProgress: Double = 0
    @Published var transferStatus = ""
    
    private let client = ZimSyncClient()
    
    struct FileToShare {
        let url: URL
        let size: Int64
        let type: UTType
    }
    
    func processSharedItems(_ items: [Any]) {
        // Process shared items from the share extension
        // This would extract URLs and file info from the shared items
        // For now, we'll simulate with a placeholder
        
        // In a real implementation, you'd iterate through items
        // and extract NSItemProvider data
        
        filesToShare = [
            FileToShare(
                url: URL(fileURLWithPath: "/tmp/shared_audio.wav"),
                size: 1024 * 1024 * 5, // 5MB
                type: .audio
            )
        ]
    }
    
    func startDiscovery() async {
        isScanning = true
        
        let discoveryStream = await client.startDiscovery()
        
        for await server in discoveryStream {
            discoveredServers.append(server)
        }
        
        // Stop scanning after 5 seconds
        try? await Task.sleep(nanoseconds: 5_000_000_000)
        isScanning = false
    }
    
    func stopDiscovery() async {
        await client.stopDiscovery()
        isScanning = false
    }
    
    func sendFiles() async {
        guard let server = selectedServer,
              let file = filesToShare.first else { return }
        
        isTransferring = true
        transferStatus = "Connecting to \(server.name)..."
        transferProgress = 0
        
        do {
            try await client.sendFile(at: file.url, to: server) { progress in
                Task { @MainActor in
                    self.transferProgress = progress.progress
                    self.transferStatus = "Transferring \(file.url.lastPathComponent)..."
                    
                    if progress.progress >= 1.0 {
                        self.transferStatus = "Transfer complete!"
                        
                        // Auto-dismiss after 1 second
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            // This would dismiss the share extension
                        }
                    }
                }
            }
        } catch {
            transferStatus = "Transfer failed: \(error.localizedDescription)"
        }
        
        isTransferring = false
    }
}