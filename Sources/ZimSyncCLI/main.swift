import ArgumentParser
import Foundation
import ZimSyncCore
import os.log

private let logger = Logger(subsystem: "com.zimsync", category: "CLI")

@main
@available(macOS 14.0, *)
struct ZimSyncCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "zimsync",
        abstract: "ZimSync - Fast local network file sync for audio production",
        version: "0.1.0",
        subcommands: [Discover.self, Serve.self, Test.self, Send.self]
    )
}

@available(macOS 14.0, *)
struct Discover: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Discover ZimSync devices on the network"
    )
    
    @Option(name: .shortAndLong, help: "Discovery timeout in seconds")
    var timeout: Int = 10
    
    func run() async throws {
        print("🔍 Discovering ZimSync devices for \(timeout) seconds...")
        
        let discovery = ServiceDiscovery()
        let devices = await discovery.startBrowsing()
        
        Task {
            try await Task.sleep(nanoseconds: UInt64(timeout) * 1_000_000_000)
            await discovery.stopBrowsing()
        }
        
        for await device in devices {
            print("📱 Found device: \(device.endpoint)")
            if let info = device.deviceInfo {
                print("   Name: \(info.name)")
                print("   Platform: \(info.platform)")
            }
        }
    }
}

@available(macOS 14.0, *)
struct Serve: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Start ZimSync server"
    )
    
    @Option(name: .shortAndLong, help: "Port to listen on")
    var port: UInt16 = 8080
    
    @Option(name: .shortAndLong, help: "Device name")
    var name: String = Host.current().localizedName ?? "Mac"
    
    @Option(name: .shortAndLong, help: "Directory to share")
    var directory: String = FileManager.default.currentDirectoryPath
    
    func run() async throws {
        let deviceInfo = DeviceInfo(
            id: UUID(),
            name: name,
            platform: .macOS,
            version: "0.1.0"
        )
        
        let sharedURL = URL(fileURLWithPath: directory)
        
        print("🚀 Starting ZimSync server on port \(port)")
        print("   Device: \(deviceInfo.name)")
        print("   ID: \(deviceInfo.id)")
        print("   Sharing: \(sharedURL.path)")
        
        let server = Server(port: port, deviceInfo: deviceInfo, sharedDirectory: sharedURL)
        try await server.start()
        
        print("✅ Server running. Press Ctrl+C to stop.")
        
        // Keep running until interrupted
        await withTaskCancellationHandler {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
        } onCancel: {
            Task {
                await server.stop()
            }
        }
    }
}

@available(macOS 14.0, *)
struct Test: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Test UDP connection"
    )
    
    @Argument(help: "Target host")
    var host: String
    
    @Option(name: .shortAndLong, help: "Target port")
    var port: UInt16 = 8080
    
    func run() async throws {
        print("📡 Testing connection to \(host):\(port)")
        
        let connection = NetworkConnection(host: host, port: port)
        try await connection.start()
        
        print("✅ Connected!")
        
        // Send test packet
        let testData = "Hello from ZimSync!".data(using: .utf8)!
        try await connection.send(testData)
        print("📤 Sent test packet")
        
        // Wait for response
        let response = try await connection.receive()
        if let message = String(data: response, encoding: .utf8) {
            print("📥 Received: \(message)")
        }
        
        await connection.cancel()
    }
}

@available(macOS 14.0, *)
struct Send: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Send a file to a ZimSync server"
    )
    
    @Argument(help: "File to send")
    var file: String
    
    @Argument(help: "Target host")
    var host: String
    
    @Option(name: .shortAndLong, help: "Target port")
    var port: UInt16 = 8080
    
    func run() async throws {
        print("📤 Sending file to \(host):\(port)")
        print("   File: \(file)")
        
        // Create client connection
        let connection = NetworkConnection(host: host, port: port)
        try await connection.start()
        
        print("✅ Connected to server")
        
        // Send discover packet
        let deviceInfo = DeviceInfo(
            id: UUID(),
            name: "ZimSync CLI Client",
            platform: .macOS,
            version: "0.1.0"
        )
        
        let discover = DiscoverPacket(deviceId: deviceInfo.id)
        let packet = Packet.discover(discover)
        let data = try PacketCodec.encode(packet, sequenceNumber: 1)
        
        try await connection.send(data)
        print("📡 Sent discovery packet")
        
        // Wait for response
        for _ in 0..<10 {  // Wait up to 10 seconds
            if let response = try? await connection.receive() {
                let (header, packet) = try PacketCodec.decode(response)
                print("📥 Received: \(packet.type)")
                
                switch packet {
                case .announce(let announce):
                    print("   Server: \(announce.deviceInfo.name)")
                    print("   Available space: \(announce.availableSpace / 1_000_000_000) GB")
                case .fileList(let list):
                    print("   Server has \(list.files.count) files")
                default:
                    break
                }
            }
            
            try await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second
        }
        
        await connection.cancel()
    }
}