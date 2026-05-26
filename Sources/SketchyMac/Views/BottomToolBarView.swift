import SwiftUI
import SketchyCore

struct BottomToolBarView: View {
    @Binding var toolState: ToolState
    @Binding var isSidebarVisible: Bool
    @Binding var isPinned: Bool

    var onNewDrawing: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button {
                withAnimation(.easeOut(duration: 0.18)) {
                    isSidebarVisible.toggle()
                }
            } label: {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 16, weight: .regular))
                    .toolButtonHitArea()
            }
            .help("Drawings")

            Divider()
                .frame(height: 20)
                .padding(.horizontal, 6)

            ForEach(BrushSize.allCases, id: \.rawValue) { size in
                Button {
                    toolState.brushSize = size
                } label: {
                    BrushSizeDot(size: size, isSelected: toolState.brushSize == size)
                        .toolButtonHitArea()
                }
                .help(size.title)
            }

            Button {
                toolState.isDashed.toggle()
            } label: {
                DashedToggleIcon(isSelected: toolState.isDashed)
                    .toolButtonHitArea()
            }
            .help("Dashed")

            Divider()
                .frame(height: 20)
                .padding(.horizontal, 6)

            ForEach(DrawingColor.palette, id: \.self) { color in
                Button {
                    toolState.color = color
                } label: {
                    ColorSwatch(color: color, isSelected: toolState.color == color)
                        .toolButtonHitArea()
                }
                .help(color.name)
            }

            Divider()
                .frame(height: 20)
                .padding(.horizontal, 6)

            Button(action: onNewDrawing) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .regular))
                    .toolButtonHitArea()
            }
            .help("New Drawing")

            Button {
                isPinned.toggle()
            } label: {
                Image(systemName: isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 15, weight: .regular))
                    .toolButtonHitArea()
            }
            .help("Keep Above Other Windows")
        }
        .buttonStyle(.plain)
        .foregroundColor(.primary)
        .padding(.horizontal, 8)
        .frame(height: 40)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.94))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 14, x: 0, y: 6)
    }
}

private extension View {
    func toolButtonHitArea() -> some View {
        modifier(ToolButtonHitArea())
    }
}

private struct ToolButtonHitArea: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(width: 28, height: 40)
            .contentShape(Rectangle())
    }
}

private struct BrushSizeDot: View {
    var size: BrushSize
    var isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                .frame(width: 22, height: 22)

            Circle()
                .fill(Color.primary)
                .frame(width: dotDiameter, height: dotDiameter)
        }
        .frame(width: 22, height: 22)
    }

    private var dotDiameter: CGFloat {
        switch size {
        case .small:
            return 4
        case .medium:
            return 8
        case .large:
            return 14
        }
    }
}

private struct DashedToggleIcon: View {
    var isSelected: Bool

    var body: some View {
        Circle()
            .stroke(
                isSelected ? Color.accentColor : Color.primary,
                style: StrokeStyle(lineWidth: 2, dash: [5, 4])
            )
            .frame(width: 20, height: 20)
            .overlay(
                Circle()
                    .stroke(Color.accentColor.opacity(isSelected ? 0.35 : 0), lineWidth: 6)
            )
    }
}

private struct ColorSwatch: View {
    var color: DrawingColor
    var isSelected: Bool

    var body: some View {
        Circle()
            .fill(Color(sketchyColor: color))
            .frame(width: 20, height: 20)
            .overlay(
                Circle()
                    .stroke(Color.primary.opacity(0.15), lineWidth: 1)
            )
            .overlay(
                Circle()
                    .stroke(Color.accentColor, lineWidth: isSelected ? 3 : 0)
                    .padding(-4)
            )
    }
}

private extension BrushSize {
    var title: String {
        switch self {
        case .small:
            return "Small Brush"
        case .medium:
            return "Medium Brush"
        case .large:
            return "Large Brush"
        }
    }
}

extension Color {
    init(sketchyColor: DrawingColor) {
        let hex = sketchyColor.hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)

        let red = Double((value & 0xFF0000) >> 16) / 255
        let green = Double((value & 0x00FF00) >> 8) / 255
        let blue = Double(value & 0x0000FF) / 255

        self.init(red: red, green: green, blue: blue)
    }
}
