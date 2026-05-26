import SwiftUI
import Sparkle
import SketchyCore

@main
struct SketchyMacApp: App {
    private let store = DrawingLibraryStore()
    private let sparkleUpdater = SparkleUpdater()

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

            CommandGroup(after: .newItem) {
                Button("New Drawing") {
                    NotificationCenter.default.post(name: .newSketchyDrawingRequested, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }
        }
    }
}

extension Notification.Name {
    static let newSketchyDrawingRequested = Notification.Name("SketchyMac.newDrawingRequested")
}
