import Foundation
import Compression

// MARK: - Packet Header
public struct PacketHeader {
    public static let size = 16  // bytes
    public static let magic: UInt32 = 0x5A494D53  // "ZIMS" in hex
    
    public let magic: UInt32
    public let version: UInt8
    public let type: PacketType
    public let flags: PacketFlags
    public let sequenceNumber: UInt16
    public let payloadSize: UInt32
    public let checksum: UInt32
    
    public init(type: PacketType, flags: PacketFlags = [], sequenceNumber: UInt16, payloadSize: UInt32, checksum: UInt32 = 0) {
        self.magic = PacketHeader.magic
        self.version = 1
        self.type = type
        self.flags = flags
        self.sequenceNumber = sequenceNumber
        self.payloadSize = payloadSize
        self.checksum = checksum
    }
    
    public init(magic: UInt32, version: UInt8, type: PacketType, flags: PacketFlags, sequenceNumber: UInt16, payloadSize: UInt32, checksum: UInt32) {
        self.magic = magic
        self.version = version
        self.type = type
        self.flags = flags
        self.sequenceNumber = sequenceNumber
        self.payloadSize = payloadSize
        self.checksum = checksum
    }
}

// MARK: - Packet Flags
public struct PacketFlags: OptionSet {
    public let rawValue: UInt8
    
    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
    
    public static let compressed = PacketFlags(rawValue: 1 << 0)
    public static let encrypted = PacketFlags(rawValue: 1 << 1)
    public static let lastChunk = PacketFlags(rawValue: 1 << 2)
    public static let requiresAck = PacketFlags(rawValue: 1 << 3)
}

// MARK: - Packet Types
public enum Packet {
    case discover(DiscoverPacket)
    case announce(AnnouncePacket)
    case fileList(FileListPacket)
    case fileRequest(FileRequestPacket)
    case fileData(FileDataPacket)
    case ack(AckPacket)
    case error(ErrorPacket)
    
    public var type: PacketType {
        switch self {
        case .discover: return .discover
        case .announce: return .announce
        case .fileList: return .fileList
        case .fileRequest: return .fileRequest
        case .fileData: return .fileData
        case .ack: return .ack
        case .error: return .error
        }
    }
}

// MARK: - Specific Packet Types
public struct DiscoverPacket: Codable {
    public let deviceId: UUID
    public let timestamp: Date
    
    public init(deviceId: UUID) {
        self.deviceId = deviceId
        self.timestamp = Date()
    }
}

public struct AnnouncePacket: Codable {
    public let deviceInfo: DeviceInfo
    public let availableSpace: Int64
    public let supportedFeatures: [String]
    
    public init(deviceInfo: DeviceInfo, availableSpace: Int64) {
        self.deviceInfo = deviceInfo
        self.availableSpace = availableSpace
        self.supportedFeatures = ["compression", "chunking", "resume"]
    }
}

public struct FileListPacket: Codable {
    public let files: [FileMetadata]
    public let totalSize: Int64
    
    public init(files: [FileMetadata]) {
        self.files = files
        self.totalSize = files.reduce(0) { $0 + $1.size }
    }
}

public struct FileRequestPacket: Codable {
    public let fileId: UUID
    public let startOffset: Int64
    public let chunkSize: Int32
    public let compressionType: CompressionType?
    
    public enum CompressionType: String, Codable {
        case zlib
        case lz4
        case lzma
        case none
    }
    
    public init(fileId: UUID, startOffset: Int64 = 0, chunkSize: Int32 = 65536, compressionType: CompressionType? = .zlib) {
        self.fileId = fileId
        self.startOffset = startOffset
        self.chunkSize = chunkSize
        self.compressionType = compressionType
    }
}

public struct FileDataPacket: Codable {
    public let fileId: UUID
    public let chunkIndex: UInt32
    public let offset: Int64
    public let totalChunks: UInt32
    public let data: Data
    public let originalSize: Int32?  // If compressed
    
    public init(fileId: UUID, chunkIndex: UInt32, offset: Int64, totalChunks: UInt32, data: Data, originalSize: Int32? = nil) {
        self.fileId = fileId
        self.chunkIndex = chunkIndex
        self.offset = offset
        self.totalChunks = totalChunks
        self.data = data
        self.originalSize = originalSize
    }
}

public struct AckPacket: Codable {
    public let sequenceNumber: UInt16
    public let receivedBitmap: Data?  // For selective ACK
    
    public init(sequenceNumber: UInt16, receivedBitmap: Data? = nil) {
        self.sequenceNumber = sequenceNumber
        self.receivedBitmap = receivedBitmap
    }
}

public struct ErrorPacket: Codable {
    public let code: ErrorCode
    public let message: String
    public let details: [String: String]?
    
    public enum ErrorCode: Int, Codable {
        case fileNotFound = 404
        case insufficientSpace = 507
        case checksumMismatch = 409
        case unsupportedFormat = 415
        case timeout = 408
    }
    
    public init(code: ErrorCode, message: String, details: [String: String]? = nil) {
        self.code = code
        self.message = message
        self.details = details
    }
}