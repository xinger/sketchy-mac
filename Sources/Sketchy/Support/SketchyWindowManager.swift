import AppKit
import SwiftUI
import SketchyCore

final class SketchyWindowManager: NSObject, NSWindowDelegate {
    private let store: DrawingLibraryStore
    private var windows: [ObjectIdentifier: NSWindow] = [:]

    init(store: DrawingLibraryStore) {
        self.store = store
    }

    func openWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 650),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        let content = SketchWindowView(store: store)
            .frame(minWidth: 720, minHeight: 480)

        window.contentViewController = NSHostingController(rootView: content)
        window.minSize = NSSize(width: 720, height: 480)
        window.delegate = self
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        windows[ObjectIdentifier(window)] = window
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else {
            return
        }

        windows.removeValue(forKey: ObjectIdentifier(window))
    }
}
