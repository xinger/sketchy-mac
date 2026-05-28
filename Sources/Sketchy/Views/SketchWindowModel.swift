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
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false

    private let historyLimit = 50
    private let store: DrawingLibraryStore
    private let autosaveScheduler = AutosaveScheduler(interval: 0.5)
    private var canvasSize = CanvasSize(width: 900, height: 650)
    private var undoStack: [Drawing] = []
    private var redoStack: [Drawing] = []
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

        recordUndoStep()
        drawing.strokes.append(stroke)
        markDrawingChanged()
    }

    func insertImage(_ image: DrawingImage) {
        recordUndoStep()
        drawing.images.append(image)
        markDrawingChanged()
    }

    func undo() {
        guard let previousDrawing = undoStack.popLast() else {
            updateHistoryAvailability()
            return
        }

        activeStroke = nil
        appendRedoStep(drawing)
        restoreDrawingSnapshot(previousDrawing)
    }

    func redo() {
        guard let nextDrawing = redoStack.popLast() else {
            updateHistoryAvailability()
            return
        }

        activeStroke = nil
        appendUndoStep(drawing)
        restoreDrawingSnapshot(nextDrawing)
    }

    func newDrawing() {
        flushAutosave()
        drawing = Drawing(updatedAt: Date())
        activeStroke = nil
        resetHistory()
    }

    func selectDrawing(id: DrawingID) {
        flushAutosave()
        guard let loaded = try? store.loadDrawing(id: id) else {
            return
        }

        drawing = loaded
        activeStroke = nil
        resetHistory()
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
        let hasSavedDrawing = summaries.contains { $0.id == drawingToSave.id }
            || cachedDrawings[drawingToSave.id] != nil
        guard drawingToSave.hasPersistableContent || hasSavedDrawing else {
            autosaveScheduler.cancel()
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

    private func recordUndoStep() {
        appendUndoStep(drawing)
        redoStack.removeAll()
        updateHistoryAvailability()
    }

    private func appendUndoStep(_ snapshot: Drawing) {
        undoStack.append(snapshot)
        trimHistoryStack(&undoStack)
    }

    private func appendRedoStep(_ snapshot: Drawing) {
        redoStack.append(snapshot)
        trimHistoryStack(&redoStack)
    }

    private func restoreDrawingSnapshot(_ snapshot: Drawing) {
        var restoredDrawing = snapshot
        restoredDrawing.updatedAt = Date()
        drawing = restoredDrawing
        updateHistoryAvailability()
        scheduleAutosave()
    }

    private func markDrawingChanged() {
        drawing.updatedAt = Date()
        scheduleAutosave()
    }

    private func resetHistory() {
        undoStack.removeAll()
        redoStack.removeAll()
        updateHistoryAvailability()
    }

    private func updateHistoryAvailability() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }

    private func trimHistoryStack(_ stack: inout [Drawing]) {
        guard stack.count > historyLimit else {
            return
        }

        stack.removeFirst(stack.count - historyLimit)
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
