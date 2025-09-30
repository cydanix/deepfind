import Foundation
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var signalSources: [DispatchSourceSignal] = []
    private var statusItem: NSStatusItem?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupSignalHandlers()
        setupStatusBarItem()
        
        // Start Meilisearch server
        Task {
            let success = await MeilisearchManager.shared.start()
            if success {
                Logger.log("Meilisearch server started successfully", log: Logger.general)
            } else {
                Logger.log("Failed to start Meilisearch server", log: Logger.general)
            }
        }
        
        Logger.log("Application did finish launching", log: Logger.general)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        Logger.log("Application will terminate", log: Logger.general)
        
        // Stop Meilisearch server synchronously to ensure it completes before app exits
        MeilisearchManager.shared.stopSyncForTermination()
        Logger.log("Meilisearch server stopped", log: Logger.general)
    }

    private func setupStatusBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "DeepFind")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show \(DeepFindAppName)", action: #selector(showApp), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    @objc private func showApp() {
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setupSignalHandlers() {
        // Handle SIGINT (Ctrl+C)
        let sigintSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        sigintSource.setEventHandler {
            Logger.log("Received SIGINT (Ctrl+C)", log: Logger.general)
            MeilisearchManager.shared.stopSyncForTermination()
            NSApplication.shared.terminate(nil)
        }
        sigintSource.resume()
        signalSources.append(sigintSource)
        
        // Handle SIGTERM
        let sigtermSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        sigtermSource.setEventHandler {
            Logger.log("Received SIGTERM", log: Logger.general)
            MeilisearchManager.shared.stopSyncForTermination()
            NSApplication.shared.terminate(nil)
        }
        sigtermSource.resume()
        signalSources.append(sigtermSource)
        
        // Ignore the default signal handlers
        signal(SIGINT, SIG_IGN)
        signal(SIGTERM, SIG_IGN)
    }
    
    deinit {
        signalSources.forEach { $0.cancel() }
    }
}
