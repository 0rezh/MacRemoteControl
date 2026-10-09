import CoreGraphics

/// Un raccourci clavier : une touche + des modificateurs.
struct Shortcut: Sendable {
    let key: CGKeyCode
    var flags: CGEventFlags = []
}

/// Codes de touches macOS (clavier ANSI).
enum KeyCode {
    static let f: CGKeyCode = 3
    static let returnKey: CGKeyCode = 36
    static let tab: CGKeyCode = 48
    static let space: CGKeyCode = 49
    static let delete: CGKeyCode = 51
    static let escape: CGKeyCode = 53
    static let left: CGKeyCode = 123
    static let right: CGKeyCode = 124

    /// Touches spéciales envoyées par nom depuis le téléphone (`{"type":"key","key":"tab"}`).
    static let named: [String: CGKeyCode] = [
        "return": returnKey,
        "tab": tab,
        "space": space,
        "delete": delete,
        "escape": escape,
    ]
}
