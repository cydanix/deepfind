import SwiftUI
import AppKit

// Helper to access NSWindow and observe full screen changes
struct WindowAccessor: NSViewRepresentable {
    @Binding var isFullScreen: Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                context.coordinator.observe(window: window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let window = nsView.window {
            context.coordinator.observe(window: window)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isFullScreen: $isFullScreen)
    }

    class Coordinator: NSObject, NSWindowDelegate {
        var isFullScreen: Binding<Bool>
        private var observedWindow: NSWindow?

        init(isFullScreen: Binding<Bool>) {
            self.isFullScreen = isFullScreen
        }

        func observe(window: NSWindow) {
            if observedWindow !== window {
                observedWindow?.delegate = nil
                observedWindow = window
                window.delegate = self
                isFullScreen.wrappedValue = (window.styleMask.contains(.fullScreen))
            }
        }

        func windowDidEnterFullScreen(_ notification: Notification) {
            isFullScreen.wrappedValue = true
        }
        func windowDidExitFullScreen(_ notification: Notification) {
            isFullScreen.wrappedValue = false
        }
    }
}
