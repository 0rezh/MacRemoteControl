import AppKit
import CoreGraphics

/// Simule la souris avec CGEvent (même permission Accessibilité que le clavier).
@MainActor
final class MouseManager {

    private var isLeftDown = false
    private var lastTarget: (point: CGPoint, time: TimeInterval)?
    private var lastPress: (button: MouseButton, time: TimeInterval, location: CGPoint, count: Int64)?

    func handle(_ event: PointerEvent) {
        switch event {
        case let .move(dx, dy): move(dx: dx, dy: dy)
        case let .scroll(dx, dy): scroll(dx: dx, dy: dy)
        case let .click(button):
            press(button, isDown: true)
            press(button, isDown: false)
        case let .button(button, isDown): press(button, isDown: isDown)
        case .release:
            if isLeftDown { press(.left, isDown: false) }
        }
    }

    /// Position du curseur. Juste après un déplacement envoyé, macOS renvoie encore l'ancienne
    /// position : on repart alors de la dernière position envoyée, sinon des mouvements se perdent.
    private var cursorLocation: CGPoint? {
        if let last = lastTarget, ProcessInfo.processInfo.systemUptime - last.time < Constants.Mouse.positionMemory {
            return last.point
        }
        return CGEvent(source: nil)?.location
    }

    private func move(dx: Double, dy: Double) {
        guard let current = cursorLocation else { return }
        let target = clamp(CGPoint(x: current.x + dx, y: current.y + dy), from: current)
        lastTarget = (target, ProcessInfo.processInfo.systemUptime)
        let type: CGEventType = isLeftDown ? .leftMouseDragged : .mouseMoved
        guard let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: target, mouseButton: .left) else { return }
        event.setIntegerValueField(.mouseEventDeltaX, value: Int64(dx.rounded()))
        event.setIntegerValueField(.mouseEventDeltaY, value: Int64(dy.rounded()))
        event.post(tap: .cghidEventTap)
    }

    /// Défilement « naturel » comme sur iPhone : le contenu suit les doigts.
    private func scroll(dx: Double, dy: Double) {
        let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: Int32(dy.rounded()),
            wheel2: Int32(dx.rounded()),
            wheel3: 0
        )
        event?.post(tap: .cghidEventTap)
    }

    private func press(_ button: MouseButton, isDown: Bool) {
        guard let location = cursorLocation else { return }
        if button == .left {
            guard isLeftDown != isDown else { return }
            isLeftDown = isDown
        }

        let clickCount = isDown ? nextClickCount(for: button, at: location) : (lastPress?.count ?? 1)
        let (type, cgButton): (CGEventType, CGMouseButton) = switch (button, isDown) {
        case (.left, true): (.leftMouseDown, .left)
        case (.left, false): (.leftMouseUp, .left)
        case (.right, true): (.rightMouseDown, .right)
        case (.right, false): (.rightMouseUp, .right)
        }

        guard let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: location, mouseButton: cgButton) else { return }
        event.setIntegerValueField(.mouseEventClickState, value: clickCount)
        event.post(tap: .cghidEventTap)
    }

    private func nextClickCount(for button: MouseButton, at location: CGPoint) -> Int64 {
        let now = ProcessInfo.processInfo.systemUptime
        var count: Int64 = 1
        if let last = lastPress,
           last.button == button,
           now - last.time < NSEvent.doubleClickInterval,
           hypot(location.x - last.location.x, location.y - last.location.y) < Constants.Mouse.doubleClickTolerance {
            count = last.count + 1
        }
        lastPress = (button, now, location, count)
        return count
    }

    /// Garde le curseur sur un écran (le passage d'un écran à l'autre reste possible).
    private func clamp(_ point: CGPoint, from current: CGPoint) -> CGPoint {
        let displays = activeDisplayBounds()
        if displays.contains(where: { $0.contains(point) }) { return point }
        guard let bounds = displays.first(where: { $0.contains(current) }) ?? displays.first else { return point }
        return CGPoint(
            x: min(max(point.x, bounds.minX), bounds.maxX - 1),
            y: min(max(point.y, bounds.minY), bounds.maxY - 1)
        )
    }

    private func activeDisplayBounds() -> [CGRect] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &displays, &count) == .success else { return [] }
        return displays.prefix(Int(count)).map { CGDisplayBounds($0) }
    }
}
