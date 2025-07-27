import SwiftUI
import ZimSyncCore
import Network
import os.log

private let logger = Logger(subsystem: "com.zimsync.macos", category: "App")

@main
struct ZimSyncApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        MenuBarExtra("ZimSync", systemImage: "antenna.radiowaves.left.and.right") {
            ZimSyncMenuView()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.menu)
        
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon - we're menu bar only
        NSApp.setActivationPolicy(.accessory)
        logger.info("ZimSync started")
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // Keep running when windows are closed
    }
}

@MainActor
class AppState: ObservableObject {
    @Published var isServerRunning = false
    @Published var sharedDirectory: URL
    @Published var discoveredDevices: [DiscoveredDevice] = []
    @Published var activeTransfers: [TransferInfo] = []
    @Published var serverPort: UInt16 = 8080
    
    private var server: Server?
    private var discovery: ServiceDiscovery?
    
    struct DiscoveredDevice: Identifiable {
        let id = UUID()
        let name: String
        let endpoint: NWEndpoint
        let deviceInfo: DeviceInfo?
    }
    
    struct TransferInfo: Identifiable {
        let id = UUID()
        let fileName: String
        let progress: Double
        let speed: String
        let direction: Direction
        
        enum Direction {
            case sending, receiving
        }
    }
    
    init() {
        // Default to ~/Music/ZimSync
        let musicDir = FileManager.default.urls(for: .musicDirectory, in: .userDomainMask).first!
        self.sharedDirectory = musicDir.appendingPathComponent("ZimSync")
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: sharedDirectory, withIntermediateDirectories: true)
    }
    
    func startServer() async {
        guard !isServerRunning else { return }
        
        do {
            let deviceInfo = DeviceInfo(
                id: UUID(),
                name: Host.current().localizedName ?? "Mac Studio",
                platform: .macOS,
                version: "1.0.0"
            )
            
            server = Server(port: serverPort, deviceInfo: deviceInfo, sharedDirectory: sharedDirectory)
            try await server?.start()
            
            // Start discovery
            discovery = ServiceDiscovery()
            await startDiscovery()
            
            isServerRunning = true
            logger.info("Server started on port \(self.serverPort)")
            
        } catch {
            logger.error("Failed to start server: \(error)")
        }
    }
    
    func stopServer() async {
        guard isServerRunning else { return }
        
        await server?.stop()
        await discovery?.stopBrowsing()
        
        server = nil
        discovery = nil
        isServerRunning = false
        discoveredDevices.removeAll()
        
        logger.info("Server stopped")
    }
    
    private func startDiscovery() async {
        guard let discovery = discovery else { return }
        
        let devices = await discovery.startBrowsing()
        
        Task {
            for await device in devices {
                let discoveredDevice = DiscoveredDevice(
                    name: "Unknown Device",
                    endpoint: device.endpoint,
                    deviceInfo: device.deviceInfo
                )
                
                await MainActor.run {
                    discoveredDevices.append(discoveredDevice)
                }
            }
        }
    }
    
    func openSharedDirectory() {
        NSWorkspace.shared.open(sharedDirectory)
    }
    
    func selectSharedDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = sharedDirectory
        
        if panel.runModal() == .OK, let url = panel.url {
            sharedDirectory = url
        }
    }
}