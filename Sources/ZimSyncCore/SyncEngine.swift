import Foundation
import Network
import os.log

private let logger = Logger(subsystem: "com.zimsync", category: "SyncEngine")

@available(macOS 14.0, iOS 17.0, *)
public actor SyncEngine {
    private let deviceInfo: DeviceInfo
    private let fileTransfer = FileTransferManager()
    private var sequenceNumber: UInt16 = 0
    private var sharedFiles: [FileMetadata] = []
    private let sharedDirectory: URL
    
    public init(deviceInfo: DeviceInfo, sharedDirectory: URL) {
        self.deviceInfo = deviceInfo
        self.sharedDirectory = sharedDirectory
    }
    
    // MARK: - Handle incoming packets
    
    public func handlePacket(_ data: Data, from connection: NWConnection) async throws {
        let (_, packet) = try PacketCodec.decode(data)
        
        logger.info("Received packet type: \(String(describing: packet.type)) from \(String(describing: connection.endpoint))")
        
        switch packet {
        case .discover(let discoverPacket):
            try await handleDiscover(discoverPacket, from: connection)
            
        case .fileList(let fileListPacket):
            try await handleFileList(fileListPacket, from: connection)
            
        case .fileRequest(let requestPacket):
            try await handleFileRequest(requestPacket, from: connection)
            
        case .fileData(let dataPacket):
            try await handleFileData(dataPacket, from: connection)
            
        case .ack(let ackPacket):
            await handleAck(ackPacket)
            
        default:
            logger.warning("Unhandled packet type: \(String(describing: packet.type))")
        }
    }
    
    // MARK: - Packet handlers
    
    private func handleDiscover(_ packet: DiscoverPacket, from connection: NWConnection) async throws {
        logger.info("Discovery from device: \(packet.deviceId)")
        
        // Respond with announce
        let announce = AnnouncePacket(
            deviceInfo: deviceInfo,
            availableSpace: getAvailableSpace()
        )
        
        let response = Packet.announce(announce)
        try await send(response, to: connection)
        
        // Send file list
        await updateSharedFiles()
        let fileList = FileListPacket(files: sharedFiles)
        try await send(.fileList(fileList), to: connection)
    }
    
    private func handleFileList(_ packet: FileListPacket, from connection: NWConnection) async throws {
        logger.info("Received file list with \(packet.files.count) files, total size: \(packet.totalSize) bytes")
        
        // In a real app, you'd show this to the user for selection
        // For demo, just log the files
        for file in packet.files {
            logger.info("  - \(file.path) (\(file.size) bytes)")
        }
    }
    
    private func handleFileRequest(_ packet: FileRequestPacket, from connection: NWConnection) async throws {
        logger.info("File request for chunk \(packet.startOffset / Int64(packet.chunkSize)) of file \(packet.fileId)")
        
        // Find the file
        guard let fileMetadata = sharedFiles.first(where: { $0.id == packet.fileId }) else {
            let error = ErrorPacket(code: .fileNotFound, message: "File not found")
            try await send(.error(error), to: connection)
            return
        }
        
        let filePath = sharedDirectory.appendingPathComponent(fileMetadata.path).path
        
        // Start transfer session if needed
        let _ = try await fileTransfer.startSending(file: fileMetadata, from: filePath)
        
        // Send requested chunk
        let chunkIndex = UInt32(packet.startOffset / Int64(packet.chunkSize))
        if let dataPacket = try await fileTransfer.getNextChunk(for: packet.fileId, chunkIndex: chunkIndex) {
            try await send(.fileData(dataPacket), to: connection)
        }
    }
    
    private func handleFileData(_ packet: FileDataPacket, from connection: NWConnection) async throws {
        logger.info("Received chunk \(packet.chunkIndex + 1)/\(packet.totalChunks) for file \(packet.fileId)")
        
        // In a real implementation, you'd have already set up the transfer
        // For now, just ACK
        let ack = AckPacket(sequenceNumber: sequenceNumber)
        try await send(.ack(ack), to: connection)
    }
    
    private func handleAck(_ packet: AckPacket) async {
        logger.debug("Received ACK for sequence \(packet.sequenceNumber)")
    }
    
    // MARK: - Sending packets
    
    private func send(_ packet: Packet, to connection: NWConnection) async throws {
        sequenceNumber &+= 1
        let data = try PacketCodec.encode(packet, sequenceNumber: sequenceNumber)
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }
    
    // MARK: - File management
    
    private func updateSharedFiles() async {
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: sharedDirectory,
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
            
            sharedFiles = []
            for url in contents where url.hasDirectoryPath == false {
                if let metadata = try? await fileTransfer.prepareFileForTransfer(at: url.path) {
                    sharedFiles.append(metadata)
                }
            }
            
            logger.info("Sharing \(self.sharedFiles.count) files from \(self.sharedDirectory.path)")
        } catch {
            logger.error("Failed to list files: \(error)")
        }
    }
    
    private func getAvailableSpace() -> Int64 {
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: sharedDirectory.path)
            return attributes[.systemFreeSize] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
}