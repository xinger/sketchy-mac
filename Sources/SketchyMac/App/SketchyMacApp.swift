import SwiftUI
import SketchyCore

@main
struct SketchyMacApp: App {
    private let store = DrawingLibraryStore()

    var body: some Scene {
        WindowGroup("Sketchy") {
            SketchWindowView(store: store)
                .frame(minWidth: 720, minHeight: 480)
        }
        .commands {
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
