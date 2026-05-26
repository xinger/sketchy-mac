import SwiftUI
import SketchyCore

struct HistorySidebarView: View {
    var summaries: [DrawingSummary]
    var cachedDrawings: [DrawingID: Drawing]
    var selectedID: DrawingID
    var onSelect: (DrawingID) -> Void
    var onClose: () -> Void
    var onNewDrawing: () -> Void
    var onHoverChange: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Drawings")
                    .font(.headline)

                Spacer()

                Button(action: onNewDrawing) {
                    Image(systemName: "plus")
                }
                .help("New Drawing")

                Button(action: onClose) {
                    Image(systemName: "xmark")
                }
                .help("Hide")
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.top, 14)

            if summaries.isEmpty {
                Spacer()
                Text("No saved drawings")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(summaries) { summary in
                            Button {
                                onSelect(summary.id)
                            } label: {
                                HistoryRow(
                                    summary: summary,
                                    drawing: cachedDrawings[summary.id],
                                    isSelected: summary.id == selectedID
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 12)
                }
            }
        }
        .frame(width: 160)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.96))
        .overlay(
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(width: 1),
            alignment: .trailing
        )
        .onHover(perform: onHoverChange)
    }
}

private struct HistoryRow: View {
    var summary: DrawingSummary
    var drawing: Drawing?
    var isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            DrawingThumbnail(drawing: drawing)
                .aspectRatio(1.5, contentMode: .fit)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(NSColor.textBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )

            Text(summary.title)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(8)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
        )
    }
}

private struct DrawingThumbnail: View {
    var drawing: Drawing?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let drawing, !drawing.strokes.isEmpty {
                    let bounds = DrawingBounds(strokes: drawing.strokes)

                    ForEach(drawing.strokes) { stroke in
                        Path { path in
                            append(stroke: stroke, to: &path, bounds: bounds, size: proxy.size)
                        }
                        .stroke(
                            Color(sketchyColor: stroke.color),
                            style: StrokeStyle(
                                lineWidth: max(1.2, CGFloat(stroke.width.lineWidth) * 0.45),
                                lineCap: .round,
                                lineJoin: .round,
                                dash: stroke.isDashed ? [5, 5] : []
                            )
                        )
                    }
                } else {
                    Image(systemName: "scribble")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary.opacity(0.6))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .clipped()
    }

    private func append(
        stroke: DrawingStroke,
        to path: inout Path,
        bounds: DrawingBounds,
        size: CGSize
    ) {
        guard let first = stroke.points.first else {
            return
        }

        path.move(to: bounds.project(first, into: size))
        for point in stroke.points.dropFirst() {
            path.addLine(to: bounds.project(point, into: size))
        }
    }
}

private struct DrawingBounds {
    var minX: Double
    var minY: Double
    var maxX: Double
    var maxY: Double

    init(strokes: [DrawingStroke]) {
        let points = strokes.flatMap(\.points)
        minX = points.map(\.x).min() ?? 0
        minY = points.map(\.y).min() ?? 0
        maxX = points.map(\.x).max() ?? 1
        maxY = points.map(\.y).max() ?? 1
    }

    func project(_ point: DrawingPoint, into size: CGSize) -> CGPoint {
        let padding: CGFloat = 12
        let drawableWidth = max(size.width - padding * 2, 1)
        let drawableHeight = max(size.height - padding * 2, 1)
        let sourceWidth = max(maxX - minX, 1)
        let sourceHeight = max(maxY - minY, 1)
        let scale = min(Double(drawableWidth) / sourceWidth, Double(drawableHeight) / sourceHeight)

        let scaledWidth = sourceWidth * scale
        let scaledHeight = sourceHeight * scale
        let offsetX = Double((size.width - CGFloat(scaledWidth)) / 2)
        let offsetY = Double((size.height - CGFloat(scaledHeight)) / 2)

        return CGPoint(
            x: offsetX + (point.x - minX) * scale,
            y: offsetY + (point.y - minY) * scale
        )
    }
}
