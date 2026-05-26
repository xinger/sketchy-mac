import AppKit
import SwiftUI
import SketchyCore

struct SketchWindowView: View {
    @StateObject private var model: SketchWindowModel
    @State private var window: NSWindow?
    @State private var hoverHideWorkItem: DispatchWorkItem?
    @State private var isLeftEdgeHovering = false
    @State private var leftEdgeProximity: CGFloat = 0
    @State private var isRightEdgeHovering = false
    @State private var rightEdgeProximity: CGFloat = 0
    @State private var isRightEdgeClickFeedbackVisible = false
    @State private var isRightEdgeHoverSuppressed = false
    @State private var rightEdgeClickFeedbackWorkItem: DispatchWorkItem?
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
                        toolState: $model.toolState
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
            rightEdgeClickFeedbackWorkItem?.cancel()
            model.flushAutosave()
            window?.level = .normal
        }
    }

    private var leftHoverStrip: some View {
        ZStack(alignment: .leading) {
            Color.clear

            Image(systemName: "sidebar.left")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.primary.opacity(edgeCueOpacity(for: leftEdgeProximity)))
                .frame(width: 24, height: 44)
                .padding(.leading, 12)
                .opacity(isLeftEdgeHovering && !model.isSidebarVisible ? 1 : 0)
                .animation(.easeOut(duration: 0.12), value: isLeftEdgeHovering)
                .animation(.easeOut(duration: 0.12), value: model.isSidebarVisible)

            EdgeHoverTrackingView(
                side: .left,
                onHoverChange: handleLeftEdgeHover(_:proximity:),
                onClick: { setSidebarVisible(true) }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
            .frame(width: 36)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .zIndex(2)
    }

    private var rightNewDrawingHoverStrip: some View {
        HStack {
            Spacer()

            ZStack(alignment: .trailing) {
                Color.clear

                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(
                        isRightEdgeClickFeedbackVisible
                            ? .accentColor
                            : .primary.opacity(edgeCueOpacity(for: rightEdgeProximity))
                    )
                    .frame(width: 24, height: 44)
                    .padding(.trailing, 12)
                    .opacity(shouldShowRightEdgePlus ? 1 : 0)
                    .animation(.easeOut(duration: 0.12), value: shouldShowRightEdgePlus)
                    .animation(.easeOut(duration: 0.08), value: isRightEdgeClickFeedbackVisible)

                EdgeHoverTrackingView(
                    side: .right,
                    onHoverChange: handleRightEdgeHover(_:proximity:),
                    onClick: handleRightEdgeTap
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: 36)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .help("New Drawing")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .zIndex(2)
    }

    private var shouldShowRightEdgePlus: Bool {
        isRightEdgeClickFeedbackVisible || (isRightEdgeHovering && !isRightEdgeHoverSuppressed)
    }

    private func edgeCueOpacity(for proximity: CGFloat) -> Double {
        let clamped = min(max(Double(proximity), 0), 1)
        return 0.18 + (0.22 * clamped)
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

    private func handleLeftEdgeHover(_ isHovering: Bool, proximity: CGFloat) {
        withAnimation(.easeOut(duration: 0.14)) {
            isLeftEdgeHovering = isHovering
            leftEdgeProximity = isHovering ? proximity : 0
        }

        if !isHovering {
            scheduleSidebarHide()
            return
        }

        cancelSidebarHide()
    }

    private func handleSidebarHover(_ isHovering: Bool) {
        if isHovering {
            cancelSidebarHide()
        } else {
            scheduleSidebarHide()
        }
    }

    private func handleRightEdgeHover(_ isHovering: Bool, proximity: CGFloat) {
        if isHovering {
            withAnimation(.easeOut(duration: 0.12)) {
                isRightEdgeHovering = !isRightEdgeHoverSuppressed
                rightEdgeProximity = proximity
            }
        } else {
            rightEdgeClickFeedbackWorkItem?.cancel()
            rightEdgeClickFeedbackWorkItem = nil
            isRightEdgeHoverSuppressed = false

            withAnimation(.easeOut(duration: 0.12)) {
                isRightEdgeHovering = false
                isRightEdgeClickFeedbackVisible = false
                rightEdgeProximity = 0
            }
        }
    }

    private func handleRightEdgeTap() {
        model.newDrawing()

        rightEdgeClickFeedbackWorkItem?.cancel()
        isRightEdgeHoverSuppressed = true

        withAnimation(.easeOut(duration: 0.08)) {
            isRightEdgeHovering = false
            isRightEdgeClickFeedbackVisible = true
        }

        let workItem = DispatchWorkItem {
            withAnimation(.easeOut(duration: 0.14)) {
                isRightEdgeClickFeedbackVisible = false
            }
        }
        rightEdgeClickFeedbackWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16, execute: workItem)
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

private enum EdgeCueSide {
    case left
    case right
}

private struct EdgeHoverTrackingView: NSViewRepresentable {
    var side: EdgeCueSide
    var onHoverChange: (Bool, CGFloat) -> Void
    var onClick: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            side: side,
            onHoverChange: onHoverChange,
            onClick: onClick
        )
    }

    func makeNSView(context: Context) -> TrackingView {
        TrackingView(coordinator: context.coordinator)
    }

    func updateNSView(_ nsView: TrackingView, context: Context) {
        context.coordinator.side = side
        context.coordinator.onHoverChange = onHoverChange
        context.coordinator.onClick = onClick
    }

    final class Coordinator {
        var side: EdgeCueSide
        var onHoverChange: (Bool, CGFloat) -> Void
        var onClick: () -> Void

        init(
            side: EdgeCueSide,
            onHoverChange: @escaping (Bool, CGFloat) -> Void,
            onClick: @escaping () -> Void
        ) {
            self.side = side
            self.onHoverChange = onHoverChange
            self.onClick = onClick
        }
    }

    final class TrackingView: NSView {
        private var trackingArea: NSTrackingArea?
        private let coordinator: Coordinator

        init(coordinator: Coordinator) {
            self.coordinator = coordinator
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()

            if let trackingArea {
                removeTrackingArea(trackingArea)
            }

            let trackingArea = NSTrackingArea(
                rect: bounds,
                options: [.activeInActiveApp, .inVisibleRect, .mouseEnteredAndExited, .mouseMoved],
                owner: self,
                userInfo: nil
            )
            addTrackingArea(trackingArea)
            self.trackingArea = trackingArea
        }

        override func mouseEntered(with event: NSEvent) {
            updateHover(with: event)
        }

        override func mouseMoved(with event: NSEvent) {
            updateHover(with: event)
        }

        override func mouseExited(with event: NSEvent) {
            coordinator.onHoverChange(false, 0)
        }

        override func mouseDown(with event: NSEvent) {
            coordinator.onClick()
        }

        private func updateHover(with event: NSEvent) {
            let location = convert(event.locationInWindow, from: nil)
            let width = max(bounds.width, 1)
            let rawProximity: CGFloat

            switch coordinator.side {
            case .left:
                rawProximity = 1 - (location.x / width)
            case .right:
                rawProximity = location.x / width
            }

            let proximity = min(max(rawProximity, 0), 1)
            coordinator.onHoverChange(true, proximity)
        }
    }
}
