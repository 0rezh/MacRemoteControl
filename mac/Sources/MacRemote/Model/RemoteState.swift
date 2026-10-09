/// État renvoyé au téléphone : quelle app est au premier plan et quel profil de raccourcis s'applique.
struct RemoteState: Encodable, Sendable {
    let app: String
    let profile: String
    let accessibility: Bool
}
