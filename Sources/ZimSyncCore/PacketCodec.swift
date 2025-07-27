import Foundation
import CryptoKit
import Compression
import os.log

private let logger = Logger(subsystem: "com.zimsync", category: "PacketCodec")

public struct PacketCodec {
    private static let maxPacketSize: Int = 65536  // 64KB max UDP packet
    
    // MARK: - Encoding
    
    public static func encode(_ packet: Packet, sequenceNumber: UInt16) throws -> Data {
        // Encode payload
        let payload: Data
        switch packet {
        case .discover(let p):
            payload = try JSONEncoder().encode(p)
        case .announce(let p):
            payload = try JSONEncoder().encode(p)
        case .fileList(let p):
            payload = try JSONEncoder().encode(p)
        case .fileRequest(let p):
            payload = try JSONEncoder().encode(p)
        case .fileData(let p):
            payload = try JSONEncoder().encode(p)
        case .ack(let p):
            payload = try JSONEncoder().encode(p)
        case .error(let p):
            payload = try JSONEncoder().encode(p)
        }
        
        // Calculate checksum
        let checksum = calculateChecksum(payload)
        
        // Create header
        let header = PacketHeader(
            type: packet.type,
            flags: [],
            sequenceNumber: sequenceNumber,
            payloadSize: UInt32(payload.count),
            checksum: checksum
        )
        
        // Combine header and payload
        var data = Data()
        data.append(header.encode())
        data.append(payload)
        
        guard data.count <= maxPacketSize else {
            throw ZimSyncError.invalidPacket
        }
        
        return data
    }
    
    // MARK: - Decoding
    
    public static func decode(_ data: Data) throws -> (header: PacketHeader, packet: Packet) {
        guard data.count >= PacketHeader.size else {
            throw ZimSyncError.invalidPacket
        }
        
        // Decode header
        let headerData = data.prefix(PacketHeader.size)
        let header = try PacketHeader.decode(headerData)
        
        // Verify magic number
        guard header.magic == PacketHeader.magic else {
            throw ZimSyncError.invalidPacket
        }
        
        // Extract payload
        let payloadStart = PacketHeader.size
        let payloadEnd = payloadStart + Int(header.payloadSize)
        guard payloadEnd <= data.count else {
            throw ZimSyncError.invalidPacket
        }
        
        let payload = data[payloadStart..<payloadEnd]
        
        // Verify checksum
        let calculatedChecksum = calculateChecksum(payload)
        guard calculatedChecksum == header.checksum else {
            throw ZimSyncError.checksumMismatch
        }
        
        // Decode packet based on type
        let packet: Packet
        switch header.type {
        case .discover:
            let p = try JSONDecoder().decode(DiscoverPacket.self, from: payload)
            packet = .discover(p)
        case .announce:
            let p = try JSONDecoder().decode(AnnouncePacket.self, from: payload)
            packet = .announce(p)
        case .fileList:
            let p = try JSONDecoder().decode(FileListPacket.self, from: payload)
            packet = .fileList(p)
        case .fileRequest:
            let p = try JSONDecoder().decode(FileRequestPacket.self, from: payload)
            packet = .fileRequest(p)
        case .fileData:
            let p = try JSONDecoder().decode(FileDataPacket.self, from: payload)
            packet = .fileData(p)
        case .ack:
            let p = try JSONDecoder().decode(AckPacket.self, from: payload)
            packet = .ack(p)
        case .error:
            let p = try JSONDecoder().decode(ErrorPacket.self, from: payload)
            packet = .error(p)
        }
        
        return (header, packet)
    }
    
    // MARK: - Compression
    
    public static func compress(_ data: Data, algorithm: compression_algorithm = COMPRESSION_ZLIB) throws -> Data {
        let destinationSize = data.count
        var destinationData = Data(count: destinationSize)
        
        let result = data.withUnsafeBytes { sourceBuffer in
            destinationData.withUnsafeMutableBytes { destinationBuffer in
                compression_encode_buffer(
                    destinationBuffer.bindMemory(to: UInt8.self).baseAddress!,
                    destinationSize,
                    sourceBuffer.bindMemory(to: UInt8.self).baseAddress!,
                    data.count,
                    nil,
                    algorithm
                )
            }
        }
        
        guard result > 0 else {
            throw ZimSyncError.invalidPacket
        }
        
        destinationData.removeSubrange(result..<destinationSize)
        
        // Only use compressed if it's actually smaller
        if destinationData.count < data.count {
            logger.debug("Compressed \(data.count) bytes to \(destinationData.count) bytes (\(Int(Double(destinationData.count) / Double(data.count) * 100))%)")
            return destinationData
        } else {
            return data
        }
    }
    
    public static func decompress(_ data: Data, algorithm: compression_algorithm = COMPRESSION_ZLIB) throws -> Data {
        let destinationSize = data.count * 4  // Estimate 4x expansion
        var destinationData = Data(count: destinationSize)
        
        let result = data.withUnsafeBytes { sourceBuffer in
            destinationData.withUnsafeMutableBytes { destinationBuffer in
                compression_decode_buffer(
                    destinationBuffer.bindMemory(to: UInt8.self).baseAddress!,
                    destinationSize,
                    sourceBuffer.bindMemory(to: UInt8.self).baseAddress!,
                    data.count,
                    nil,
                    algorithm
                )
            }
        }
        
        guard result > 0 else {
            throw ZimSyncError.invalidPacket
        }
        
        destinationData.removeSubrange(result..<destinationSize)
        return destinationData
    }
    
    // MARK: - Audio-Aware Compression
    
    public static func compressAudioChunk(_ data: Data, fileExtension: String) throws -> (data: Data, algorithm: compression_algorithm?) {
        // For already compressed formats, don't recompress
        let compressedFormats = ["mp3", "m4a", "aac", "ogg", "opus", "flac"]
        if compressedFormats.contains(fileExtension.lowercased()) {
            return (data, nil)
        }
        
        // For uncompressed audio (WAV, AIFF), use ZLIB
        let compressed = try compress(data, algorithm: COMPRESSION_ZLIB)
        if compressed.count < Int(Double(data.count) * 0.9) {  // Only if >10% savings
            return (compressed, COMPRESSION_ZLIB)
        }
        
        return (data, nil)
    }
    
    // MARK: - Helpers
    
    private static func calculateChecksum(_ data: Data) -> UInt32 {
        let hash = SHA256.hash(data: data)
        let hashData = Data(hash)
        // Take first 4 bytes of hash as checksum
        return hashData.prefix(4).withUnsafeBytes { $0.load(as: UInt32.self) }
    }
}

// MARK: - Header Encoding/Decoding
extension PacketHeader {
    func encode() -> Data {
        var data = Data()
        data.append(contentsOf: withUnsafeBytes(of: magic.bigEndian) { Array($0) })
        data.append(version)
        data.append(type.rawValue)
        data.append(flags.rawValue)
        data.append(contentsOf: withUnsafeBytes(of: sequenceNumber.bigEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: payloadSize.bigEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: checksum.bigEndian) { Array($0) })
        return data
    }
    
    static func decode(_ data: Data) throws -> PacketHeader {
        guard data.count >= PacketHeader.size else {
            throw ZimSyncError.invalidPacket
        }
        
        var offset = 0
        
        // Magic number
        var magicBytes = Data(data[offset..<offset+4])
        let magic = magicBytes.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        offset += 4
        
        let version = data[offset]
        offset += 1
        
        guard let type = PacketType(rawValue: data[offset]) else {
            throw ZimSyncError.invalidPacket
        }
        offset += 1
        
        let flags = PacketFlags(rawValue: data[offset])
        offset += 1
        
        // Sequence number
        var seqBytes = Data(data[offset..<offset+2])
        let sequenceNumber = seqBytes.withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
        offset += 2
        
        // Payload size
        var sizeBytes = Data(data[offset..<offset+4])
        let payloadSize = sizeBytes.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        offset += 4
        
        // Checksum
        var checksumBytes = Data(data[offset..<offset+4])
        let checksum = checksumBytes.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        
        return PacketHeader(
            magic: magic,
            version: version,
            type: type,
            flags: flags,
            sequenceNumber: sequenceNumber,
            payloadSize: payloadSize,
            checksum: checksum
        )
    }
}