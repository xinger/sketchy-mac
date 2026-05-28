import AppKit
import SwiftUI
import Sparkle
import SketchyCore

@main
struct SketchyApp: App {
    private let store: DrawingLibraryStore
    private let windowManager: SketchyWindowManager
    private let sparkleUpdater = SparkleUpdater()

    init() {
        let store = DrawingLibraryStore()
        self.store = store
        windowManager = SketchyWindowManager(store: store)
    }

    var body: some Scene {
        WindowGroup("Sketchy") {
            SketchWindowView(store: store)
                .frame(minWidth: 720, minHeight: 480)
        }
        .commands {
            CommandGroup(after: .appInfo) {
                if let updater = sparkleUpdater.updater {
                    CheckForUpdatesCommand(updater: updater)
                }
            }

            CommandGroup(replacing: .newItem) {
                Button("New Drawing") {
                    NotificationCenter.default.post(
                        name: .newSketchyDrawingRequested,
                        object: NSApp.keyWindow ?? NSApp.mainWindow
                    )
                }
                .keyboardShortcut("n", modifiers: [.command])

                Button("New Window") {
                    windowManager.openWindow()
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }

            CommandGroup(replacing: .undoRedo) {
                Button("Undo") {
                    NotificationCenter.default.post(
                        name: .undoSketchyDrawingRequested,
                        object: NSApp.keyWindow ?? NSApp.mainWindow
                    )
                }
                .keyboardShortcut("z", modifiers: [.command])

                Button("Redo") {
                    NotificationCenter.default.post(
                        name: .redoSketchyDrawingRequested,
                        object: NSApp.keyWindow ?? NSApp.mainWindow
                    )
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
            }
        }
    }
}

extension Notification.Name {
    static let newSketchyDrawingRequested = Notification.Name("Sketchy.newDrawingRequested")
    static let undoSketchyDrawingRequested = Notification.Name("Sketchy.undoDrawingRequested")
    static let redoSketchyDrawingRequested = Notification.Name("Sketchy.redoDrawingRequested")
}
