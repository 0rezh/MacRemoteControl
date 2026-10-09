import CoreGraphics

/// Touches de modification du clavier Mac.
enum KeyModifier: String, Decodable, Sendable, CaseIterable {
    case shift
    case control
    case option
    case command

    var flag: CGEventFlags {
        switch self {
        case .shift: .maskShift
        case .control: .maskControl
        case .option: .maskAlternate
        case .command: .maskCommand
        }
    }

    /// Touche de gauche du clavier Mac (pour les événements « flagsChanged »).
    var keyCode: CGKeyCode {
        switch self {
        case .shift: 56
        case .control: 59
        case .option: 58
        case .command: 55
        }
    }
}

extension Set where Element == KeyModifier {
    var flags: CGEventFlags {
        reduce(into: []) { $0.formUnion($1.flag) }
    }
}

/// Saisie envoyée depuis le clavier de l'iPhone.
enum KeyboardInput: Sendable {
    /// Texte tapé sans modificateur.
    case text(String)
    /// Une touche (caractère ou nom : « tab », « delete », « return »…) avec des modificateurs (⌘C…).
    case key(String, modifiers: Set<KeyModifier>)
    /// Modificateurs verrouillés sur le téléphone : ils restent enfoncés sur le Mac (⌘ tenu + tab, tab…).
    case holdModifiers(Set<KeyModifier>)
}
