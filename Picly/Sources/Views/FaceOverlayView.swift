import Cocoa

class FaceOverlayView: NSView {
    var faceRects: [(id: String, rect: NSRect)] = []
    var onFaceClick: ((String) -> Void)?
    private var faceTrackingAreas: [String: NSTrackingArea] = [:]

    // Pass-through: let mouse events fall through to views below when no faces
    override func hitTest(_ point: NSPoint) -> NSView? {
        for face in faceRects {
            if convertRectToView(face.rect).contains(point) {
                return self
            }
        }
        return nil
    }

    override func draw(_ dirtyRect: NSRect) {
        guard !faceRects.isEmpty, let ctx = NSGraphicsContext.current?.cgContext else { return }

        ctx.setStrokeColor(NSColor.controlAccentColor.cgColor)
        ctx.setLineWidth(2.0)
        ctx.setFillColor(NSColor.controlAccentColor.withAlphaComponent(0.08).cgColor)

        for face in faceRects {
            let scaledRect = convertRectToView(face.rect)
            ctx.addRect(scaledRect)
            ctx.drawPath(using: .fillStroke)
        }
    }

    func updateFaces(_ faces: [(id: String, rect: NSRect)]) {
        faceRects = faces
        rebuildTrackingAreas()
        needsDisplay = true
    }

    private func convertRectToView(_ rect: NSRect) -> NSRect {
        NSRect(x: rect.origin.x * bounds.width,
               y: rect.origin.y * bounds.height,
               width: rect.size.width * bounds.width,
               height: rect.size.height * bounds.height)
    }

    private func rebuildTrackingAreas() {
        for (_, area) in faceTrackingAreas { removeTrackingArea(area) }
        faceTrackingAreas.removeAll()

        for face in faceRects {
            let scaledRect = convertRectToView(face.rect)
            let area = NSTrackingArea(rect: scaledRect, options: [.activeInActiveApp, .mouseEnteredAndExited],
                                       owner: self, userInfo: ["faceId": face.id])
            addTrackingArea(area)
            faceTrackingAreas[face.id] = area
        }
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        for face in faceRects {
            if convertRectToView(face.rect).contains(point) {
                onFaceClick?(face.id)
                return
            }
        }
    }
}
