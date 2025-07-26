import Foundation
import Compression
import CryptoKit
import os.log

private let logger = Logger(subsystem: "com.zimsync", category: "FileTransfer")

@available(macOS 14.0, iOS 17.0, *)
public actor FileTransferManager {
    public static let defaultChunkSize: Int32 = 32768  // 32KB chunks for UDP
    
    private var activeTransfers: [UUID: TransferSession] = [:]
    private let fileManager = FileManager.default
    
    public init() {}
    
    // MARK: - Sending Files
    
    public func prepareFileForTransfer(at path: String) async throws -> FileMetadata {
        let url = URL(fileURLWithPath: path)
        
        guard fileManager.fileExists(atPath: path) else {
            throw ZimSyncError.fileNotFound(path)
        }
        
        let attributes = try fileManager.attributesOfItem(atPath: path)
        let size = attributes[.size] as? Int64 ?? 0
        let modifiedDate = attributes[.modificationDate] as? Date ?? Date()
        
        // Calculate checksum
        let checksum = try await calculateFileChecksum(url: url)
        
        // Extract audio metadata if applicable
        let audioMetadata = try? await extractAudioMetadata(url: url)
        
        return FileMetadata(
            id: UUID(),
            path: url.lastPathComponent,
            size: size,
            modifiedDate: modifiedDate,
            checksum: checksum,
            audioMetadata: audioMetadata
        )
    }
    
    public func startSending(file: FileMetadata, from path: String) async throws -> TransferSession {
        let url = URL(fileURLWithPath: path)
        let handle = try FileHandle(forReadingFrom: url)
        
        let session = TransferSession(
            fileId: file.id,
            filePath: path,
            totalSize: file.size,
            chunkSize: Self.defaultChunkSize,
            direction: .sending,
            handle: handle
        )
        
        activeTransfers[file.id] = session
        return session
    }
    
    public func getNextChunk(for fileId: UUID, chunkIndex: UInt32) async throws -> FileDataPacket? {
        guard let session = activeTransfers[fileId] else {
            throw ZimSyncError.fileNotFound("No active transfer for file")
        }
        
        let offset = Int64(chunkIndex) * Int64(session.chunkSize)
        guard offset < session.totalSize else {
            return nil  // End of file
        }
        
        // Seek to position
        try session.handle?.seek(toOffset: UInt64(offset))
        
        // Read chunk
        let remainingBytes = session.totalSize - offset
        let bytesToRead = min(Int(session.chunkSize), Int(remainingBytes))
        guard let data = session.handle?.readData(ofLength: bytesToRead) else {
            throw ZimSyncError.fileNotFound("Failed to read file")
        }
        
        // Compress if beneficial
        let fileExtension = URL(fileURLWithPath: session.filePath).pathExtension
        let (finalData, algorithm) = try PacketCodec.compressAudioChunk(data, fileExtension: fileExtension)
        
        let totalChunks = UInt32((session.totalSize + Int64(session.chunkSize) - 1) / Int64(session.chunkSize))
        
        return FileDataPacket(
            fileId: fileId,
            chunkIndex: chunkIndex,
            offset: offset,
            totalChunks: totalChunks,
            data: finalData,
            originalSize: algorithm != nil ? Int32(data.count) : nil
        )
    }
    
    // MARK: - Receiving Files
    
    public func startReceiving(file: FileMetadata, to path: String) async throws -> TransferSession {
        let url = URL(fileURLWithPath: path)
        
        // Create directory if needed
        let directory = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        
        // Create or truncate file
        fileManager.createFile(atPath: path, contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        
        let session = TransferSession(
            fileId: file.id,
            filePath: path,
            totalSize: file.size,
            chunkSize: Self.defaultChunkSize,
            direction: .receiving,
            handle: handle
        )
        
        activeTransfers[file.id] = session
        return session
    }
    
    public func receiveChunk(_ packet: FileDataPacket) async throws {
        guard let session = activeTransfers[packet.fileId] else {
            throw ZimSyncError.fileNotFound("No active transfer for file")
        }
        
        // Decompress if needed
        let data: Data
        if let originalSize = packet.originalSize {
            data = try PacketCodec.decompress(packet.data, algorithm: COMPRESSION_ZLIB)
            guard data.count == originalSize else {
                throw ZimSyncError.checksumMismatch
            }
        } else {
            data = packet.data
        }
        
        // Write to file at correct offset
        try session.handle?.seek(toOffset: UInt64(packet.offset))
        session.handle?.write(data)
        
        // Update progress
        await session.markChunkReceived(packet.chunkIndex)
        
        logger.info("Received chunk \(packet.chunkIndex)/\(packet.totalChunks) for file \(packet.fileId)")
    }
    
    public func completeTransfer(fileId: UUID) async throws {
        guard let session = activeTransfers[fileId] else {
            throw ZimSyncError.fileNotFound("No active transfer")
        }
        
        // Close file handle
        try session.handle?.close()
        
        // Verify file if receiving
        if await session.direction == .receiving {
            let filePath = await session.filePath
            let url = URL(fileURLWithPath: filePath)
            let checksum = try await calculateFileChecksum(url: url)
            logger.info("Transfer complete. File checksum: \(checksum.base64EncodedString())")
        }
        
        activeTransfers.removeValue(forKey: fileId)
    }
    
    // MARK: - Helpers
    
    private func calculateFileChecksum(url: URL) async throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        
        var hasher = SHA256()
        let bufferSize = 1024 * 1024  // 1MB buffer
        
        while true {
            let data = handle.readData(ofLength: bufferSize)
            if data.isEmpty { break }
            hasher.update(data: data)
        }
        
        return Data(hasher.finalize())
    }
    
    private func extractAudioMetadata(url: URL) async throws -> AudioMetadata? {
        // This would use AVFoundation on a real implementation
        // For now, return nil
        return nil
    }
}

// MARK: - Transfer Session
@available(macOS 14.0, iOS 17.0, *)
public actor TransferSession {
    public let fileId: UUID
    public let filePath: String
    public let totalSize: Int64
    public let chunkSize: Int32
    public let direction: Direction
    public let handle: FileHandle?
    
    private var receivedChunks: Set<UInt32> = []
    private let startTime = Date()
    
    public enum Direction {
        case sending
        case receiving
    }
    
    init(fileId: UUID, filePath: String, totalSize: Int64, chunkSize: Int32, direction: Direction, handle: FileHandle?) {
        self.fileId = fileId
        self.filePath = filePath
        self.totalSize = totalSize
        self.chunkSize = chunkSize
        self.direction = direction
        self.handle = handle
    }
    
    public func markChunkReceived(_ chunkIndex: UInt32) {
        receivedChunks.insert(chunkIndex)
    }
    
    public var progress: Double {
        let totalChunks = (totalSize + Int64(chunkSize) - 1) / Int64(chunkSize)
        return Double(receivedChunks.count) / Double(totalChunks)
    }
    
    public var transferRate: Double {
        let elapsed = Date().timeIntervalSince(startTime)
        let bytesTransferred = Double(receivedChunks.count) * Double(chunkSize)
        return elapsed > 0 ? bytesTransferred / elapsed : 0
    }
    
    public func getMissingChunks() -> [UInt32] {
        let totalChunks = UInt32((totalSize + Int64(chunkSize) - 1) / Int64(chunkSize))
        var missing: [UInt32] = []
        
        for i in 0..<totalChunks {
            if !receivedChunks.contains(i) {
                missing.append(i)
            }
        }
        
        return missing
    }
}