import AppKit
import CoreGraphics
import IOKit.pwr_mgt

/// Simule le clavier : touches classiques (CGEvent), touches média (événements système NX)
/// et saisie de texte depuis le clavier de l'iPhone.
@MainActor
final class KeyboardManager {

    private let layout = KeyboardLayout()
    /// Modificateurs verrouillés sur le téléphone, tenus enfoncés sur le Mac.
    private var heldModifiers: Set<KeyModifier> = []

    /// Touches média, valeurs de NX_KEYTYPE_* (IOKit/hidsystem/ev_keymap.h).
    enum MediaKey: Int {
        case soundUp = 0
        case soundDown = 1
        case mute = 7
        case play = 16
    }

    func perform(_ action: RemoteAction, using profile: AppProfile) {
        wakeDisplay()
        switch action {
        case .playPause: press(.play)
        case .volumeUp: press(.soundUp)
        case .volumeDown: press(.soundDown)
        case .mute: press(.mute)
        case .seekBackward: press(profile.seekBackward)
        case .seekForward: press(profile.seekForward)
        case .fullscreen: press(profile.fullscreen)
        case .escape: press(Shortcut(key: KeyCode.escape))
        }
    }

    func handle(_ input: KeyboardInput) {
        wakeDisplay()
        switch input {
        case .text(let text): type(text)
        case .key(let key, let modifiers): press(key: key, modifiers: modifiers)
        case .holdModifiers(let modifiers): hold(modifiers)
        }
    }

    /// Relâche tout modificateur tenu (téléphone déconnecté).
    func releaseModifiers() {
        hold([])
    }

    func press(_ shortcut: Shortcut) {
        let source = CGEventSource(stateID: .hidSystemState)
        for isDown in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: shortcut.key, keyDown: isDown) else { continue }
            event.flags = event.flags.union(shortcut.flags)
            event.post(tap: .cghidEventTap)
        }
    }

    func press(_ key: MediaKey) {
        for isDown in [true, false] {
            let state = isDown ? 0xA : 0xB
            let event = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(state << 8)),
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: (key.rawValue << 16) | (state << 8),
                data2: -1
            )
            event?.cgEvent?.post(tap: .cghidEventTap)
        }
    }

    /// Chaque caractère passe par sa vraie touche si la disposition du Mac l'a (marche dans toutes les apps),
    /// sinon il est injecté tel quel (emoji, lettres absentes du clavier…).
    private func type(_ text: String) {
        for character in text {
            if character.isNewline {
                press(Shortcut(key: KeyCode.returnKey, flags: heldModifiers.flags))
            } else {
                press(character: String(character), flags: heldModifiers.flags)
            }
        }
    }

    /// `key` est un nom de touche (« tab », « delete »…) ou un caractère (« c » pour ⌘C).
    private func press(key: String, modifiers: Set<KeyModifier>) {
        let flags = modifiers.union(heldModifiers).flags
        if let keyCode = KeyCode.named[key] {
            press(Shortcut(key: keyCode, flags: flags))
        } else {
            press(character: key, flags: flags)
        }
    }

    private func press(character: String, flags: CGEventFlags) {
        if let stroke = layout.stroke(for: character) {
            press(Shortcut(key: stroke.keyCode, flags: stroke.flags.union(flags)))
        } else {
            typeUnicode(character, flags: flags)
        }
    }

    private func typeUnicode(_ string: String, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)
        let utf16 = Array(string.utf16)
        for isDown in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: isDown) else { continue }
            event.flags = flags
            event.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
            event.post(tap: .cghidEventTap)
        }
    }

    /// Enfonce ou relâche les modificateurs (événements « flagsChanged »), comme des doigts posés sur ⌘, ⌥…
    private func hold(_ modifiers: Set<KeyModifier>) {
        let source = CGEventSource(stateID: .hidSystemState)
        var current = heldModifiers
        for modifier in heldModifiers.subtracting(modifiers) {
            current.remove(modifier)
            postModifier(modifier, isDown: false, flags: current.flags, source: source)
        }
        for modifier in modifiers.subtracting(heldModifiers) {
            current.insert(modifier)
            postModifier(modifier, isDown: true, flags: current.flags, source: source)
        }
        heldModifiers = current
    }

    private func postModifier(_ modifier: KeyModifier, isDown: Bool, flags: CGEventFlags, source: CGEventSource?) {
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: modifier.keyCode, keyDown: isDown) else { return }
        event.type = .flagsChanged
        event.flags = flags
        event.post(tap: .cghidEventTap)
    }

    /// Rallume l'écran s'il s'était mis en veille pendant une pause.
    private func wakeDisplay() {
        var assertionID: IOPMAssertionID = 0
        IOPMAssertionDeclareUserActivity("Mac Remote Control" as CFString, kIOPMUserActiveLocal, &assertionID)
    }
}
