import Carbon.HIToolbox
import CoreGraphics

/// Retrouve la touche (et les modificateurs) qui produit un caractère avec la disposition de clavier
/// active du Mac (AZERTY, QWERTY…). Sans ça, ⌘ + « q » ne déclencherait pas ⌘Q sur un clavier AZERTY.
@MainActor
final class KeyboardLayout {

    struct KeyStroke {
        let keyCode: CGKeyCode
        let flags: CGEventFlags
    }

    private var layoutID: String?
    private var strokes: [String: KeyStroke] = [:]

    func stroke(for character: String) -> KeyStroke? {
        refreshIfNeeded()
        return strokes[character]
    }

    /// Recalcule la table quand l'utilisateur change de disposition de clavier.
    private func refreshIfNeeded() {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue() else { return }
        let id = TISGetInputSourceProperty(source, kTISPropertyInputSourceID)
            .map { Unmanaged<CFString>.fromOpaque($0).takeUnretainedValue() as String }
        guard id != layoutID else { return }
        layoutID = id
        strokes = Self.makeStrokes(for: source)
    }

    private static func makeStrokes(for source: TISInputSource) -> [String: KeyStroke] {
        guard let rawData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return [:] }
        let data = Unmanaged<CFData>.fromOpaque(rawData).takeUnretainedValue() as Data

        let modifierStates: [(carbon: UInt32, flags: CGEventFlags)] = [
            (0, []),
            (UInt32(shiftKey >> 8) & 0xFF, .maskShift),
            (UInt32(optionKey >> 8) & 0xFF, .maskAlternate),
            (UInt32((shiftKey | optionKey) >> 8) & 0xFF, [.maskShift, .maskAlternate]),
        ]

        var strokes: [String: KeyStroke] = [:]
        data.withUnsafeBytes { buffer in
            guard let layout = buffer.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return }
            for state in modifierStates {
                for keyCode in 0..<128 {
                    var deadKeyState: UInt32 = 0
                    var length = 0
                    var characters = [UniChar](repeating: 0, count: 4)
                    let status = UCKeyTranslate(
                        layout, UInt16(keyCode), UInt16(kUCKeyActionDown), state.carbon, UInt32(LMGetKbdType()),
                        0, &deadKeyState, characters.count, &length, &characters
                    )
                    guard status == noErr, length > 0, deadKeyState == 0 else { continue }
                    let string = String(utf16CodeUnits: characters, count: length)
                    if strokes[string] == nil {
                        strokes[string] = KeyStroke(keyCode: CGKeyCode(keyCode), flags: state.flags)
                    }
                }
            }
        }
        return strokes
    }
}
