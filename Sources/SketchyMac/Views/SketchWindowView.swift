import AppKit
import SwiftUI
import SketchyCore

struct SketchWindowView: View {
    @StateObject private var model: SketchWindowModel
    @State private var window: NSWindow?
    @State private var hoverRevealWorkItem: DispatchWorkItem?
    @State private var hoverHideWorkItem: DispatchWorkItem?
    @State private var viewport = ViewportTransform()

    init(store: DrawingLibraryStore) {
        _model = StateObject(wrappedValue: SketchWindowModel(store: store))
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Color(NSColor.underPageBackgroundColor)
                    .ignoresSafeArea()

                DrawingCanvasRepresentable(
                    strokes: model.displayedStrokes,
                    activeStrokeID: model.activeStroke?.id,
                    viewport: $viewport,
                    onBegin: model.beginStroke(at:),
                    onAppend: model.appendStrokePoint(_:),
                    onEnd: model.finishStroke
                )
                .background(Color.clear)
                .onAppear {
                    model.updateCanvasSize(
                        width: Double(proxy.size.width),
                        height: Double(proxy.size.height)
                    )
                }
                .onChange(of: proxy.size) { size in
                    model.updateCanvasSize(width: Double(size.width), height: Double(size.height))
                }

                leftHoverStrip

                if model.isSidebarVisible {
                    HistorySidebarView(
                        summaries: model.summaries,
                        cachedDrawings: model.cachedDrawings,
                        selectedID: model.drawing.id,
                        onSelect: model.selectDrawing(id:),
                        onClose: { setSidebarVisible(false) },
                        onNewDrawing: model.newDrawing,
                        onHoverChange: handleSidebarHover
                    )
                    .transition(.move(edge: .leading).combined(with: .opacity))
                }

                VStack {
                    Spacer()

                    BottomToolBarView(
                        toolState: $model.toolState,
                        isSidebarVisible: Binding(
                            get: { model.isSidebarVisible },
                            set: { setSidebarVisible($0) }
                        ),
                        isPinned: $model.isPinned,
                        onNewDrawing: model.newDrawing
                    )
                    .padding(.bottom, 28)
                }
                .frame(maxWidth: .infinity)
            }
            .animation(.easeOut(duration: 0.18), value: model.isSidebarVisible)
        }
        .background(
            WindowAccessor { resolvedWindow in
                window = resolvedWindow
                configureWindow(resolvedWindow)
                applyWindowLevel(to: resolvedWindow)
            }
        )
        .onChange(of: model.isPinned) { _ in
            applyWindowLevel(to: window)
        }
        .onReceive(NotificationCenter.default.publisher(for: .newSketchyDrawingRequested)) { _ in
            model.newDrawing()
        }
        .onDisappear {
            model.flushAutosave()
            window?.level = .normal
        }
    }

    private var leftHoverStrip: some View {
        Color.clear
            .frame(width: 24)
            .contentShape(Rectangle())
            .onHover { isHovering in
                handleLeftEdgeHover(isHovering)
            }
    }

    private func handleLeftEdgeHover(_ isHovering: Bool) {
        hoverRevealWorkItem?.cancel()

        if !isHovering {
            scheduleSidebarHide()
            return
        }

        cancelSidebarHide()

        guard !model.isSidebarVisible else {
            return
        }

        let workItem = DispatchWorkItem {
            setSidebarVisible(true)
        }
        hoverRevealWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55, execute: workItem)
    }

    private func handleSidebarHover(_ isHovering: Bool) {
        if isHovering {
            cancelSidebarHide()
        } else {
            scheduleSidebarHide()
        }
    }

    private func scheduleSidebarHide() {
        hoverHideWorkItem?.cancel()

        guard model.isSidebarVisible else {
            return
        }

        let workItem = DispatchWorkItem {
            setSidebarVisible(false)
        }
        hoverHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24, execute: workItem)
    }

    private func cancelSidebarHide() {
        hoverHideWorkItem?.cancel()
        hoverHideWorkItem = nil
    }

    private func setSidebarVisible(_ isVisible: Bool) {
        hoverRevealWorkItem?.cancel()
        if isVisible {
            cancelSidebarHide()
        }

        withAnimation(.easeOut(duration: 0.18)) {
            model.isSidebarVisible = isVisible
        }
    }

    private func configureWindow(_ window: NSWindow?) {
        guard let window else {
            return
        }

        window.title = "Sketchy"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.toolbar = nil
    }

    private func applyWindowLevel(to window: NSWindow?) {
        window?.level = model.isPinned ? .floating : .normal
    }
}
