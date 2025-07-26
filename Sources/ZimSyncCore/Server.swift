import Foundation
import Network
import os.log

private let logger = Logger(subsystem: "com.zimsync", category: "Server")

@available(macOS 14.0, iOS 17.0, *)
public actor Server {
    private let port: UInt16
    private let deviceInfo: DeviceInfo
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.zimsync.server", qos: .userInitiated)
    private var connections: Set<ConnectionHandler> = []
    private let syncEngine: SyncEngine
    
    public init(port: UInt16, deviceInfo: DeviceInfo, sharedDirectory: URL) {
        self.port = port
        self.deviceInfo = deviceInfo
        self.syncEngine = SyncEngine(deviceInfo: deviceInfo, sharedDirectory: sharedDirectory)
    }
    
    public func start() async throws {
        let parameters = NWParameters.udp
        parameters.allowLocalEndpointReuse = true
        parameters.includePeerToPeer = true
        
        guard let port = NWEndpoint.Port(rawValue: port) else {
            throw ZimSyncError.connectionFailed
        }
        
        let listener = try NWListener(using: parameters, on: port)
        
        listener.stateUpdateHandler = { state in
            logger.info("Server state: \(String(describing: state))")
            switch state {
            case .ready:
                logger.info("Server listening on port \(self.port)")
            case .failed(let error):
                logger.error("Server failed: \(error)")
            default:
                break
            }
        }
        
        listener.newConnectionHandler = { [weak self] connection in
            Task {
                await self?.handleNewConnection(connection)
            }
        }
        
        self.listener = listener
        listener.start(queue: queue)
        
        // Also start advertising via Bonjour
        let discovery = ServiceDiscovery()
        try await discovery.startAdvertising(on: self.port, deviceInfo: deviceInfo)
    }
    
    private func handleNewConnection(_ connection: NWConnection) {
        logger.info("New UDP connection from \(String(describing: connection.endpoint))")
        
        let handler = ConnectionHandler(connection: connection, syncEngine: syncEngine)
        connections.insert(handler)
        
        Task {
            await handler.start()
            // Remove when done
            connections.remove(handler)
        }
    }
    
    public func stop() {
        listener?.cancel()
        listener = nil
        for connection in connections {
            Task {
                await connection.cancel()
            }
        }
        connections.removeAll()
    }
}

@available(macOS 14.0, iOS 17.0, *)
private actor ConnectionHandler: Hashable {
    private let id = UUID()
    private let connection: NWConnection
    private let queue = DispatchQueue(label: "com.zimsync.connection", qos: .userInitiated)
    private let syncEngine: SyncEngine
    
    init(connection: NWConnection, syncEngine: SyncEngine) {
        self.connection = connection
        self.syncEngine = syncEngine
    }
    
    func start() async {
        connection.stateUpdateHandler = { state in
            logger.debug("Connection state: \(String(describing: state))")
        }
        
        connection.start(queue: queue)
        
        // Start receiving messages
        await receiveMessages()
    }
    
    private func receiveMessages() async {
        while true {
            do {
                let message = try await receive()
                await handleMessage(message)
            } catch {
                logger.error("Receive error: \(error)")
                break
            }
        }
    }
    
    private func receive() async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            connection.receiveMessage { data, _, isComplete, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let data = data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: ZimSyncError.invalidPacket)
                }
            }
        }
    }
    
    private func handleMessage(_ data: Data) async {
        // Try to decode as a ZimSync packet first
        do {
            try await syncEngine.handlePacket(data, from: connection)
        } catch {
            // Fall back to echo for testing
            if let message = String(data: data, encoding: .utf8) {
                let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
                logger.info("Received text: \(trimmedMessage)")
                
                // Echo back with proper formatting
                let response = "ZimSync Echo: \(trimmedMessage)\n".data(using: .utf8)!
                await send(response)
            } else {
                logger.error("Failed to handle message: \(error)")
            }
        }
    }
    
    private func send(_ data: Data) async {
        connection.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                logger.error("Send error: \(error)")
            } else {
                logger.debug("Sent response: \(data.count) bytes")
            }
        })
    }
    
    func cancel() {
        connection.cancel()
    }
    
    // Hashable conformance
    static func == (lhs: ConnectionHandler, rhs: ConnectionHandler) -> Bool {
        lhs.id == rhs.id
    }
    
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}