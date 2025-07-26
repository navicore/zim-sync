import Foundation
import Network
import os.log

public enum ZimSyncError: LocalizedError {
    case connectionFailed
    case invalidPacket
    case fileNotFound(String)
    case checksumMismatch
    case timeout
    
    public var errorDescription: String? {
        switch self {
        case .connectionFailed:
            return "Failed to establish connection"
        case .invalidPacket:
            return "Received invalid packet format"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .checksumMismatch:
            return "File checksum verification failed"
        case .timeout:
            return "Operation timed out"
        }
    }
}

public enum PacketType: UInt8 {
    case discover = 0x01
    case announce = 0x02
    case fileList = 0x03
    case fileRequest = 0x04
    case fileData = 0x05
    case ack = 0x06
    case error = 0x07
}

public struct DeviceInfo: Codable, Hashable {
    public let id: UUID
    public let name: String
    public let platform: Platform
    public let version: String
    
    public enum Platform: String, Codable {
        case macOS
        case iOS
        case iPadOS
    }
    
    public init(id: UUID, name: String, platform: Platform, version: String) {
        self.id = id
        self.name = name
        self.platform = platform
        self.version = version
    }
}

public struct FileMetadata: Codable, Hashable {
    public let id: UUID
    public let path: String
    public let size: Int64
    public let modifiedDate: Date
    public let checksum: Data
    public let audioMetadata: AudioMetadata?
}

public struct AudioMetadata: Codable, Hashable {
    public let duration: TimeInterval
    public let sampleRate: Int
    public let channels: Int
    public let format: String
}