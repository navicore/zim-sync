import Foundation
import Network
import os.log

private let logger = Logger(subsystem: "com.zimsync", category: "Network")

@available(macOS 14.0, iOS 17.0, *)
public actor NetworkConnection {
    private let connection: NWConnection
    private let queue = DispatchQueue(label: "com.zimsync.network", qos: .userInitiated)
    
    public enum State {
        case setup
        case waiting
        case ready
        case failed(Error)
    }
    
    private var state: State = .setup
    private var continuation: AsyncThrowingStream<Data, Error>.Continuation?
    
    public init(endpoint: NWEndpoint) {
        let parameters = NWParameters.udp
        parameters.allowLocalEndpointReuse = true
        
        self.connection = NWConnection(to: endpoint, using: parameters)
    }
    
    public init(host: String, port: UInt16) {
        let parameters = NWParameters.udp
        parameters.allowLocalEndpointReuse = true
        
        self.connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(integerLiteral: port),
            using: parameters
        )
    }
    
    public func start() async throws {
        connection.stateUpdateHandler = { [weak self] newState in
            Task { [weak self] in
                await self?.handleStateUpdate(newState)
            }
        }
        
        connection.start(queue: queue)
        
        // Wait for connection to be ready
        for _ in 0..<30 { // 3 second timeout
            if case .ready = state {
                return
            }
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        
        throw ZimSyncError.timeout
    }
    
    private func handleStateUpdate(_ newState: NWConnection.State) {
        logger.debug("Connection state: \(String(describing: newState))")
        
        switch newState {
        case .ready:
            state = .ready
        case .failed(let error):
            state = .failed(error)
            continuation?.finish()
        case .cancelled:
            continuation?.finish()
        default:
            break
        }
    }
    
    public func send(_ data: Data) async throws {
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
    
    public func receive() async throws -> Data {
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
    
    public func packets() -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            self.continuation = continuation
            
            func receiveNext() {
                connection.receiveMessage { [weak self] data, _, isComplete, error in
                    guard let self = self else { return }
                    
                    if let error = error {
                        continuation.yield(with: .failure(error))
                        continuation.finish()
                    } else if let data = data {
                        continuation.yield(data)
                        if !isComplete {
                            receiveNext()
                        }
                    }
                }
            }
            
            receiveNext()
        }
    }
    
    public func cancel() {
        connection.cancel()
        continuation?.finish()
    }
}