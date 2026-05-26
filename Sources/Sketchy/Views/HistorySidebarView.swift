import AppKit
import SwiftUI
import SketchyCore

struct HistorySidebarView: View {
    var summaries: [DrawingSummary]
    var cachedDrawings: [DrawingID: Drawing]
    var selectedID: DrawingID
    var onSelect: (DrawingID) -> Void
    var onClose: () -> Void
    var onNewDrawing: () -> Void

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
            .padding(.top, 48)

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
        .frame(maxHeight: .infinity)
        .frame(width: 160)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.96))
        .overlay(
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(width: 1),
            alignment: .trailing
        )
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
                if let drawing, !drawing.strokes.isEmpty || !drawing.images.isEmpty {
                    let bounds = DrawingBounds(drawing: drawing)

                    ForEach(drawing.images) { drawingImage in
                        if let image = NSImage(data: drawingImage.data) {
                            let rect = bounds.project(drawingImage.frame, into: proxy.size)

                            Image(nsImage: image)
                                .resizable()
                                .interpolation(.medium)
                                .frame(width: rect.width, height: rect.height)
                                .position(x: rect.midX, y: rect.midY)
                        }
                    }

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

    init(drawing: Drawing) {
        let points = drawing.strokes.flatMap(\.points)
        let imagePoints = drawing.images.flatMap { image in
            [
                DrawingPoint(x: image.frame.x, y: image.frame.y),
                DrawingPoint(
                    x: image.frame.x + image.frame.width,
                    y: image.frame.y + image.frame.height
                )
            ]
        }
        let allPoints = points + imagePoints
        minX = allPoints.map(\.x).min() ?? 0
        minY = allPoints.map(\.y).min() ?? 0
        maxX = allPoints.map(\.x).max() ?? 1
        maxY = allPoints.map(\.y).max() ?? 1
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

    func project(_ frame: DrawingImageFrame, into size: CGSize) -> CGRect {
        let origin = project(DrawingPoint(x: frame.x, y: frame.y), into: size)
        let corner = project(
            DrawingPoint(x: frame.x + frame.width, y: frame.y + frame.height),
            into: size
        )

        return CGRect(
            x: min(origin.x, corner.x),
            y: min(origin.y, corner.y),
            width: abs(corner.x - origin.x),
            height: abs(corner.y - origin.y)
        )
    }
}
