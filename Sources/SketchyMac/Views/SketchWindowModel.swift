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

    init(store: DrawingLibraryStore) {
        self.store = store

        let summaries = (try? store.loadIndex()) ?? []
        if let first = summaries.first, let loaded = try? store.loadDrawing(id: first.id) {
            drawing = loaded
        } else {
            drawing = Drawing()
        }

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
        scheduleAutosave()
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

    func newDrawing() {
        flushAutosave()
        drawing = Drawing(updatedAt: Date())
        activeStroke = nil
        scheduleAutosave()
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
        let canvasSizeToSave = canvasSize
        let store = store

        autosaveScheduler.schedule {
            try? store.save(drawing: drawingToSave, canvasSize: canvasSizeToSave)
            DispatchQueue.main.async { [weak self] in
                self?.reloadSummaries()
            }
        }
    }
}
