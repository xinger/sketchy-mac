import Foundation

public enum DrawingImagePlacement {
    public static func centeredFrame(
        imageSize: CanvasSize,
        viewport: ViewportTransform,
        canvasSize: CanvasSize
    ) -> DrawingImageFrame {
        let sourceWidth = max(imageSize.width, 1)
        let sourceHeight = max(imageSize.height, 1)
        let visibleWorldWidth = max(canvasSize.width, 1) / viewport.scale
        let visibleWorldHeight = max(canvasSize.height, 1) / viewport.scale
        let maxWidth = visibleWorldWidth * 0.6
        let maxHeight = visibleWorldHeight * 0.6
        let fitScale = min(1, maxWidth / sourceWidth, maxHeight / sourceHeight)
        let width = sourceWidth * fitScale
        let height = sourceHeight * fitScale
        let center = viewport.worldPoint(
            fromScreenPoint: DrawingPoint(
                x: canvasSize.width / 2,
                y: canvasSize.height / 2
            )
        )

        return DrawingImageFrame(
            x: center.x - width / 2,
            y: center.y - height / 2,
            width: width,
            height: height
        )
    }
}
