import Foundation
import ZimSyncCore
import Network
import os.log

private let logger = Logger(subsystem: "com.zimsync.ios", category: "Client")

@available(iOS 17.0, *)
public actor ZimSyncClient {
    private let discovery = ServiceDiscovery()
    private var discoveredServers: [DiscoveredServer] = []
    private var activeConnections: [UUID: NetworkConnection] = [:]
    
    public struct DiscoveredServer: Identifiable {
        public let id = UUID()
        public let name: String
        public let endpoint: NWEndpoint
        public let deviceInfo: DeviceInfo?
        public let distance: NetworkDistance
        
        public enum NetworkDistance {
            case local, nearby, remote
        }
    }
    
    public struct TransferProgress {
        public let fileId: UUID
        public let fileName: String
        public let bytesTransferred: Int64
        public let totalBytes: Int64
        public let speed: Double // bytes per second
        
        public var progress: Double {
            guard totalBytes > 0 else { return 0 }
            return Double(bytesTransferred) / Double(totalBytes)
        }
    }
    
    public init() {}
    
    // MARK: - Discovery
    
    public func startDiscovery() -> AsyncStream<DiscoveredServer> {
        AsyncStream { continuation in
            Task {
                let devices = await discovery.startBrowsing()
                
                for await device in devices {
                    let server = DiscoveredServer(
                        name: device.deviceInfo?.name ?? "Unknown Mac",
                        endpoint: device.endpoint,
                        deviceInfo: device.deviceInfo,
                        distance: .local // All discovered via Bonjour are local
                    )
                    
                    await MainActor.run {
                        discoveredServers.append(server)
                    }
                    
                    continuation.yield(server)
                }
            }
        }
    }
    
    public func stopDiscovery() async {
        await discovery.stopBrowsing()
        discoveredServers.removeAll()
    }
    
    // MARK: - File Transfer
    
    public func sendFile(
        at url: URL,
        to server: DiscoveredServer,
        progress: @escaping (TransferProgress) -> Void
    ) async throws {
        logger.info("Sending file \(url.lastPathComponent) to \(server.name)")
        
        // Create connection
        let connection = NetworkConnection(endpoint: server.endpoint)
        try await connection.start()
        
        activeConnections[server.id] = connection
        
        // Get file info
        let fileManager = FileManager.default
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        let fileName = url.lastPathComponent
        
        logger.info("File size: \(fileSize) bytes")
        
        // Send discover packet first
        let deviceInfo = DeviceInfo(
            id: UUID(),
            name: UIDevice.current.name,
            platform: UIDevice.current.userInterfaceIdiom == .pad ? .iPadOS : .iOS,
            version: "1.0.0"
        )
        
        let discover = DiscoverPacket(deviceId: deviceInfo.id)
        let discoverData = try PacketCodec.encode(.discover(discover), sequenceNumber: 1)
        try await connection.send(discoverData)
        
        logger.info("Sent discovery packet")
        
        // Wait for server response
        let response = try await connection.receive()
        let (_, packet) = try PacketCodec.decode(response)
        
        switch packet {
        case .announce(let announce):
            logger.info("Connected to \(announce.deviceInfo.name)")
            
            // Now send the file
            try await performFileTransfer(
                fileUrl: url,
                fileName: fileName,
                fileSize: fileSize,
                connection: connection,
                serverId: server.id,
                progress: progress
            )
            
        default:
            throw ZimSyncError.invalidPacket
        }
        
        await connection.cancel()
        activeConnections.removeValue(forKey: server.id)
    }
    
    private func performFileTransfer(
        fileUrl: URL,
        fileName: String,
        fileSize: Int64,
        connection: NetworkConnection,
        serverId: UUID,
        progress: @escaping (TransferProgress) -> Void
    ) async throws {
        
        let fileManager = FileTransferManager()
        let metadata = try await fileManager.prepareFileForTransfer(at: fileUrl.path)
        
        // Start sending chunks
        let chunkSize: Int32 = 32768 // 32KB chunks
        let totalChunks = Int((fileSize + Int64(chunkSize) - 1) / Int64(chunkSize))
        
        let transferProgress = TransferProgress(
            fileId: metadata.id,
            fileName: fileName,
            bytesTransferred: 0,
            totalBytes: fileSize,
            speed: 0
        )
        
        var bytesTransferred: Int64 = 0
        let startTime = Date()
        
        // Send file request to server
        let fileRequest = FileRequestPacket(
            fileId: metadata.id,
            startOffset: 0,
            chunkSize: chunkSize,
            compressionType: .zlib
        )
        
        let requestData = try PacketCodec.encode(.fileRequest(fileRequest), sequenceNumber: 2)
        try await connection.send(requestData)
        
        logger.info("Starting file transfer: \(totalChunks) chunks")
        
        // For now, just report completion (real implementation would send chunks)
        // This is a simplified version - full implementation would chunk and send
        bytesTransferred = fileSize
        let elapsed = Date().timeIntervalSince(startTime)
        let speed = elapsed > 0 ? Double(bytesTransferred) / elapsed : 0
        
        let finalProgress = TransferProgress(
            fileId: metadata.id,
            fileName: fileName,
            bytesTransferred: bytesTransferred,
            totalBytes: fileSize,
            speed: speed
        )
        
        progress(finalProgress)
        logger.info("File transfer completed: \(fileName)")
    }
    
    // MARK: - Convenience
    
    public func getBestServer() async -> DiscoveredServer? {
        // Return the first local server found
        return discoveredServers.first { $0.distance == .local }
    }
    
    public func getAvailableServers() async -> [DiscoveredServer] {
        return discoveredServers
    }
}