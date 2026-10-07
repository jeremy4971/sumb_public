//
//  DockTileView.swift
//  updatecountdown
//
//  The Dock icon with the countdown in a red badge in the corner.
//

import Cocoa

final class DockTileView: NSView {

    /// Text in the red badge. nil draws the plain icon.
    var badge: String? {
        didSet { needsDisplay = true }
    }

    // Centered for the wide live HH:mm:ss, in the corner otherwise.
    var centersBadge = false {
        didSet { needsDisplay = true }
    }

    // Plain draw(_:) since the Dock snapshots the view as soon as display() is called.
    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.current?.imageInterpolation = .high
        NSApp.applicationIconImage?.draw(in: bounds)

        if let badge, !badge.isEmpty {
            drawBadge(text: badge)
        }
    }

    // Looks like the system Dock badge. Grows to the left into a capsule
    // when the text is wider than the circle.
    private func drawBadge(text: String) {
        let diameter = bounds.width * 0.34
        let center = NSPoint(x: bounds.width * 0.82, y: bounds.height * 0.82)
        let padding = diameter * 0.5
        let maxWidth = bounds.width * 0.9

        let font = Self.fittingFont(for: text, startSize: diameter * 0.62, maxWidth: maxWidth - padding)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
        let textWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))

        let width = min(maxWidth, max(diameter, textWidth + padding))
        let x = centersBadge ? bounds.midX - width / 2 : center.x + diameter / 2 - width
        let shape = NSRect(x: x, y: center.y - diameter / 2, width: width, height: diameter)
        NSColor.systemRed.withAlphaComponent(0.9).setFill()
        NSBezierPath(roundedRect: shape, xRadius: diameter / 2, yRadius: diameter / 2).fill()

        guard let context = NSGraphicsContext.current?.cgContext else { return }
        // Centers the drawn glyphs, so a lone "1" or "4" sits in the middle. The
        // live timer centers by advance width so it doesn't shift as digits tick.
        context.saveGState()
        defer { context.restoreGState() }
        // Image bounds include the current text position, so reset it first.
        context.textMatrix = .identity
        context.textPosition = .zero
        let ink = CTLineGetImageBounds(line, context)
        let textX = centersBadge ? shape.midX - textWidth / 2 : shape.midX - ink.midX
        context.textPosition = CGPoint(x: textX, y: shape.midY - ink.midY)
        CTLineDraw(line, context)
    }

    // Shrinks the font until the text fits, so HH:mm:ss or a long prefix stays inside.
    // Fixed-width digits keep the live countdown from jiggling.
    private static func fittingFont(for text: String, startSize: CGFloat, maxWidth: CGFloat) -> NSFont {
        var size = startSize
        while true {
            let font = NSFont.monospacedDigitSystemFont(ofSize: size, weight: .medium)
            let width = (text as NSString).size(withAttributes: [.font: font]).width
            if width <= maxWidth || size <= 8 { return font }
            size -= 1
        }
    }
}
