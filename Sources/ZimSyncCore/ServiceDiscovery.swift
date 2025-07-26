import Foundation
import Network
import os.log

private let logger = Logger(subsystem: "com.zimsync", category: "Discovery")

@available(macOS 14.0, iOS 17.0, *)
public actor ServiceDiscovery {
    public static let serviceType = "_zimsync._udp"
    public static let domain = "local."
    
    private var browser: NWBrowser?
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.zimsync.discovery", qos: .userInitiated)
    
    public struct DiscoveredDevice {
        public let endpoint: NWEndpoint
        public let deviceInfo: DeviceInfo?
    }
    
    private var devicesContinuation: AsyncStream<DiscoveredDevice>.Continuation?
    
    public init() {}
    
    // MARK: - Browsing for devices
    
    public func startBrowsing() -> AsyncStream<DiscoveredDevice> {
        AsyncStream { continuation in
            self.devicesContinuation = continuation
            
            let parameters = NWParameters()
            parameters.includePeerToPeer = true
            
            let browser = NWBrowser(
                for: .bonjour(type: Self.serviceType, domain: Self.domain),
                using: parameters
            )
            
            browser.browseResultsChangedHandler = { results, changes in
                Task {
                    await self.handleBrowseResults(results, changes: changes)
                }
            }
            
            browser.stateUpdateHandler = { newState in
                logger.debug("Browser state: \(String(describing: newState))")
                
                switch newState {
                case .failed(let error):
                    logger.error("Browser failed: \(error)")
                    continuation.finish()
                case .cancelled:
                    continuation.finish()
                default:
                    break
                }
            }
            
            self.browser = browser
            browser.start(queue: queue)
            
            continuation.onTermination = { _ in
                Task {
                    await self.stopBrowsing()
                }
            }
        }
    }
    
    private func handleBrowseResults(_ results: Set<NWBrowser.Result>, changes: Set<NWBrowser.Result.Change>) {
        for change in changes {
            switch change {
            case .added(let result):
                handleDiscoveredEndpoint(result.endpoint)
            case .removed(let result):
                logger.info("Device removed: \(String(describing: result.endpoint))")
            default:
                break
            }
        }
    }
    
    private func handleDiscoveredEndpoint(_ endpoint: NWEndpoint) {
        logger.info("Discovered device: \(String(describing: endpoint))")
        
        // Extract device info from TXT record if available
        let device = DiscoveredDevice(endpoint: endpoint, deviceInfo: nil)
        devicesContinuation?.yield(device)
    }
    
    public func stopBrowsing() {
        browser?.cancel()
        browser = nil
        devicesContinuation?.finish()
    }
    
    // MARK: - Advertising service
    
    public func startAdvertising(on port: UInt16, deviceInfo: DeviceInfo) throws {
        let parameters = NWParameters.udp
        parameters.allowLocalEndpointReuse = true
        parameters.includePeerToPeer = true
        
        guard let port = NWEndpoint.Port(rawValue: port) else {
            throw ZimSyncError.connectionFailed
        }
        
        let listener = try NWListener(using: parameters, on: port)
        
        // Set up Bonjour service with TXT record
        let txtRecord: NWTXTRecord
        if let txtData = try? JSONEncoder().encode(deviceInfo),
           let txtString = String(data: txtData, encoding: .utf8) {
            txtRecord = NWTXTRecord(["info": txtString])
        } else {
            txtRecord = NWTXTRecord()
        }
        
        listener.service = NWListener.Service(
            name: deviceInfo.name,
            type: Self.serviceType,
            domain: Self.domain,
            txtRecord: txtRecord.data
        )
        
        listener.stateUpdateHandler = { newState in
            logger.debug("Listener state: \(String(describing: newState))")
        }
        
        listener.newConnectionHandler = { connection in
            Task {
                await self.handleIncomingConnection(connection)
            }
        }
        
        self.listener = listener
        listener.start(queue: queue)
    }
    
    private func handleIncomingConnection(_ connection: NWConnection) {
        logger.info("Incoming connection: \(String(describing: connection.endpoint))")
        // Connection handling will be implemented by the sync engine
    }
    
    public func stopAdvertising() {
        listener?.cancel()
        listener = nil
    }
}