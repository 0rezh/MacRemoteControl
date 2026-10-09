/// Commandes de lecture envoyées par la télécommande.
enum RemoteAction: String, Decodable, Sendable {
    case playPause
    case seekBackward
    case seekForward
    case volumeUp
    case volumeDown
    case mute
    case fullscreen
    case escape
}
