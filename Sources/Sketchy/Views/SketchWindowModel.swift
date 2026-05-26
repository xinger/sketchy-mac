import Combine
import Foundation
import SketchyCore

final class SketchWindowModel: ObservableObject {
    @Published var drawing: Drawing
    @Published var activeStroke: DrawingStroke?
    @Published var toolState = ToolState()
    @Published var summaries: [DrawingSummary] = []
    @Published var cachedDrawings: [DrawingID: Drawing] = [:]
    @Published var isSidebarVisible = false
    @Published var isPinned = false

    private let store: DrawingLibraryStore
    private let autosaveScheduler = AutosaveScheduler(interval: 0.5)
    private var canvasSize = CanvasSize(width: 900, height: 650)
    private var cancellables = Set<AnyCancellable>()

    init(store: DrawingLibraryStore) {
        self.store = store
        drawing = Drawing(updatedAt: Date())

        NotificationCenter.default.publisher(for: .sketchyDrawingLibraryDidChange)
            .compactMap { $0.object as? URL }
            .filter { $0 == store.rootDirectory }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reloadSummaries()
            }
            .store(in: &cancellables)

        reloadSummaries()
    }

    var displayedStrokes: [DrawingStroke] {
        if let activeStroke {
            return drawing.strokes + [activeStroke]
        }

        return drawing.strokes
    }

    func updateCanvasSize(width: Double, height: Double) {
        let nextSize = CanvasSize(width: max(width, 1), height: max(height, 1))
        guard nextSize != canvasSize else {
            return
        }

        canvasSize = nextSize
        if drawing.hasPersistableContent {
            scheduleAutosave()
        }
    }

    func beginStroke(at point: DrawingPoint) {
        activeStroke = DrawingStroke(
            points: [point],
            color: toolState.color,
            width: toolState.brushSize,
            isDashed: toolState.isDashed
        )
    }

    func appendStrokePoint(_ point: DrawingPoint) {
        guard activeStroke != nil else {
            beginStroke(at: point)
            return
        }

        activeStroke?.points.append(point)
    }

    func finishStroke() {
        guard let stroke = activeStroke else {
            return
        }

        activeStroke = nil
        guard stroke.points.count > 1 else {
            return
        }

        drawing.strokes.append(stroke)
        drawing.updatedAt = Date()
        scheduleAutosave()
    }

    func insertImage(_ image: DrawingImage) {
        drawing.images.append(image)
        drawing.updatedAt = Date()
        scheduleAutosave()
    }

    func newDrawing() {
        flushAutosave()
        drawing = Drawing(updatedAt: Date())
        activeStroke = nil
    }

    func selectDrawing(id: DrawingID) {
        flushAutosave()
        guard let loaded = try? store.loadDrawing(id: id) else {
            return
        }

        drawing = loaded
        activeStroke = nil
    }

    func flushAutosave() {
        autosaveScheduler.flush()
        reloadSummaries()
    }

    func reloadSummaries() {
        summaries = (try? store.loadIndex()) ?? []
        cachedDrawings = summaries.reduce(into: [:]) { result, summary in
            if let drawing = try? store.loadDrawing(id: summary.id) {
                result[summary.id] = drawing
            }
        }
    }

    private func scheduleAutosave() {
        let drawingToSave = drawing
        guard drawingToSave.hasPersistableContent else {
            return
        }

        let canvasSizeToSave = canvasSize
        let store = store
        let rootDirectory = store.rootDirectory

        autosaveScheduler.schedule {
            guard (try? store.save(drawing: drawingToSave, canvasSize: canvasSizeToSave)) != nil else {
                return
            }

            DispatchQueue.main.async { [weak self] in
                NotificationCenter.default.post(
                    name: .sketchyDrawingLibraryDidChange,
                    object: rootDirectory
                )
                self?.reloadSummaries()
            }
        }
    }
}

extension Notification.Name {
    static let sketchyDrawingLibraryDidChange = Notification.Name("Sketchy.drawingLibraryDidChange")
}

private extension Drawing {
    var hasPersistableContent: Bool {
        !strokes.isEmpty || !images.isEmpty
    }
}
