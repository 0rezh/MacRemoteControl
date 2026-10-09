enum MouseButton: String, Decodable, Sendable {
    case left
    case right
}

/// Événements souris envoyés par le trackpad du téléphone.
enum PointerEvent: Sendable {
    case move(dx: Double, dy: Double)
    case scroll(dx: Double, dy: Double)
    case click(MouseButton)
    case button(MouseButton, isDown: Bool)
    /// Téléphone déconnecté : on relâche un éventuel clic maintenu.
    case release
}
