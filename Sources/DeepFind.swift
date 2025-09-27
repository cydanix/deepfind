import SwiftUI

@main
struct DeepFind: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var showPermissionAlert = false
    @State private var missingPermissions: [String] = []
    @State private var activeSheet: ActiveSheet?

    static var shared: DeepFind? = nil

    enum ActiveSheet: Identifiable {
        case onboarding

        var id: Int {
            switch self {
            case .onboarding: return 2
            }
        }
    }

    init() {
        Logger.log("DeepFind initialized", log: Logger.general)
        DeepFind.shared = self
    }

    private func setActiveSheet(sheet: ActiveSheet?) {
        Logger.log("Setting active sheet to \(sheet?.id ?? -1)", log: Logger.general)
        if Thread.isMainThread {
            activeSheet = sheet
        } else {
            DispatchQueue.main.async {
                self.activeSheet = sheet
            }
        }
    }

    func showNoEnoughDiskSpaceAlert(freeSpace: Int64) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Insufficient Disk Space"
            alert.informativeText = "You need at least 20GB of free disk space to download the models. Please free up some space and try again. Available: \(GenericHelper.formatSize(size: freeSpace))"
            alert.alertStyle = .critical
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .accentColor(.orange)
                .preferredColorScheme(.dark)
                .onAppear {
                    // Ensure this process registers as a normal GUI app…
                    NSApp.setActivationPolicy(.regular)
                    // …and becomes frontmost so windows get key events
                    NSApp.activate(ignoringOtherApps: true)


                    // Show onboarding on first launch
                    if !SettingsStore.shared.hasCompletedOnboarding {
                        setActiveSheet(sheet: .onboarding)
                    }
                }
                .sheet(item: $activeSheet) { sheet in
                    switch sheet {
                    case .onboarding:
                        OnboardingView()
                            .onDisappear {
                                setActiveSheet(sheet: nil)
                            }
                    }
                }
        }
        Settings {
            SettingsView()
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About \(DeepFindAppName)") {
                    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
                    let alert = NSAlert()
                    alert.messageText = "\(DeepFindAppName) \(version)"
                    alert.informativeText = "© 2025 \(DeepFindCompanyName)"
                    alert.alertStyle = .informational
                    alert.icon = NSApp.applicationIconImage
                    alert.addButton(withTitle: "OK")
                    alert.addButton(withTitle: "Visit Website")
                    let response = alert.runModal()
                    if response == .alertSecondButtonReturn {
                        if let url = URL(string: DeepFindSite) {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
                Button("Setup Guide") {
                    SettingsStore.shared.hasCompletedOnboarding = false
                    setActiveSheet(sheet: .onboarding)
                }
            }
        }
    }
}
