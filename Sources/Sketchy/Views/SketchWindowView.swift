import AppKit
import SwiftUI
import SketchyCore

struct SketchWindowView: View {
    @StateObject private var model: SketchWindowModel
    @State private var window: NSWindow?
    @State private var hoverRevealWorkItem: DispatchWorkItem?
    @State private var hoverHideWorkItem: DispatchWorkItem?
    @State private var isLeftEdgeHovering = false
    @State private var isRightEdgeHovering = false
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
                    images: model.drawing.images,
                    strokes: model.displayedStrokes,
                    activeStrokeID: model.activeStroke?.id,
                    viewport: $viewport,
                    onBegin: model.beginStroke(at:),
                    onAppend: model.appendStrokePoint(_:),
                    onEnd: model.finishStroke,
                    onInsertImage: model.insertImage(_:)
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
                rightNewDrawingHoverStrip

                HistorySidebarView(
                    summaries: model.summaries,
                    cachedDrawings: model.cachedDrawings,
                    selectedID: model.drawing.id,
                    onSelect: model.selectDrawing(id:),
                    onClose: { setSidebarVisible(false) },
                    onNewDrawing: model.newDrawing,
                    onHoverChange: handleSidebarHover
                )
                .offset(x: model.isSidebarVisible ? 0 : -168)
                .opacity(model.isSidebarVisible ? 1 : 0)
                .ignoresSafeArea(edges: .vertical)
                .allowsHitTesting(model.isSidebarVisible)
                .zIndex(3)

                VStack {
                    Spacer()

                    BottomToolBarView(
                        toolState: $model.toolState,
                        isSidebarVisible: Binding(
                            get: { model.isSidebarVisible },
                            set: { setSidebarVisible($0) }
                        ),
                        onNewDrawing: model.newDrawing
                    )
                    .padding(.bottom, 28)
                }
                .frame(maxWidth: .infinity)
                .zIndex(4)

                windowPinButton
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
        .onReceive(NotificationCenter.default.publisher(for: .newSketchyDrawingRequested)) { notification in
            guard
                let targetWindow = notification.object as? NSWindow,
                let window,
                targetWindow === window
            else {
                return
            }

            model.newDrawing()
        }
        .onDisappear {
            model.flushAutosave()
            window?.level = .normal
        }
    }

    private var leftHoverStrip: some View {
        ZStack(alignment: .leading) {
            Color.clear

            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color.primary.opacity(0.16))
                .frame(width: 4, height: 72)
                .padding(.leading, 6)
                .opacity(isLeftEdgeHovering && !model.isSidebarVisible ? 1 : 0)
                .animation(.easeOut(duration: 0.14), value: isLeftEdgeHovering)
                .animation(.easeOut(duration: 0.14), value: model.isSidebarVisible)
        }
            .frame(width: 24)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .zIndex(2)
            .onHover { isHovering in
                handleLeftEdgeHover(isHovering)
            }
            .onTapGesture {
                setSidebarVisible(true)
            }
    }

    private var rightNewDrawingHoverStrip: some View {
        HStack {
            Spacer()

            ZStack(alignment: .trailing) {
                Color.clear

                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.primary.opacity(0.32))

                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.primary.opacity(0.16))
                        .frame(width: 4, height: 72)
                }
                .padding(.trailing, 6)
                .opacity(isRightEdgeHovering ? 1 : 0)
                .animation(.easeOut(duration: 0.14), value: isRightEdgeHovering)
            }
            .frame(width: 24)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .onHover { isHovering in
                withAnimation(.easeOut(duration: 0.14)) {
                    isRightEdgeHovering = isHovering
                }
            }
            .onTapGesture {
                model.newDrawing()
            }
            .help("New Drawing")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .zIndex(2)
    }

    private var windowPinButton: some View {
        Button {
            model.isPinned.toggle()
        } label: {
            Image(systemName: model.isPinned ? "pin.fill" : "pin")
                .font(.system(size: 11, weight: .medium))
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundColor(model.isPinned ? .accentColor : .primary.opacity(0.72))
        .brightness(model.isPinned ? 0 : -0.04)
        .help("Keep Above Other Windows")
        .padding(.top, 9)
        .padding(.trailing, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .ignoresSafeArea(edges: .top)
        .zIndex(5)
    }

    private func handleLeftEdgeHover(_ isHovering: Bool) {
        hoverRevealWorkItem?.cancel()
        withAnimation(.easeOut(duration: 0.14)) {
            isLeftEdgeHovering = isHovering
        }

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
            isLeftEdgeHovering = false
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
