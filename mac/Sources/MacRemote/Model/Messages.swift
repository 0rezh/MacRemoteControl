import Foundation

/// Message téléphone → Mac. Se décode lui-même : la couche réseau ne connaît pas son format.
///
/// `{"type":"hello","token":"…"}`, `{"type":"action","action":"playPause"}`, `{"type":"ping"}`,
/// pour la souris : `move` / `scroll` (dx, dy), `click` (button), `button` (button, down),
/// et pour le clavier : `text` (text), `key` (key, modifiers), `modifiers` (held).
struct ClientMessage: Decodable, Sendable {
    let type: String
    let token: String?
    let action: RemoteAction?
    let dx: Double?
    let dy: Double?
    let button: MouseButton?
    let down: Bool?
    let text: String?
    let key: String?
    let modifiers: [KeyModifier]?
    let held: [KeyModifier]?

    init?(json: String) {
        guard let message = try? JSONDecoder().decode(Self.self, from: Data(json.utf8)) else { return nil }
        self = message
    }

    var keyboardInput: KeyboardInput? {
        switch type {
        case "text": text.map { .text($0) }
        case "key": key.map { .key($0, modifiers: Set(modifiers ?? [])) }
        case "modifiers": .holdModifiers(Set(held ?? []))
        default: nil
        }
    }

    var pointerEvent: PointerEvent? {
        switch type {
        case "move": .move(dx: dx ?? 0, dy: dy ?? 0)
        case "scroll": .scroll(dx: dx ?? 0, dy: dy ?? 0)
        case "click": button.map { .click($0) }
        case "button":
            if let button, let down { .button(button, isDown: down) } else { nil }
        default: nil
        }
    }
}

/// Message Mac → téléphone.
struct ServerMessage: Encodable, Sendable {
    let type: String
    var reason: String?
    var state: RemoteState?

    static func welcome(_ state: RemoteState) -> Self { Self(type: "welcome", state: state) }
    static func state(_ state: RemoteState) -> Self { Self(type: "state", state: state) }
    static let pong = Self(type: "pong")
    static let badToken = Self(type: "error", reason: "bad_token")
    static let tokenRevoked = Self(type: "error", reason: "token_revoked")

    var json: String {
        let data = (try? JSONEncoder().encode(self)) ?? Data()
        return String(decoding: data, as: UTF8.self)
    }
}
