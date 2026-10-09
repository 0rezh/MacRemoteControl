/// Comment le téléphone trouve le Mac : nom Bonjour (stable) ou adresse IP (si .local ne marche pas).
enum AddressMode: String, CaseIterable, Sendable {
    case bonjour
    case ip
}

enum PairingToken {
    static func generate() -> String {
        String((0..<Constants.Pairing.tokenLength).map { _ in Constants.Pairing.tokenAlphabet.randomElement()! })
    }
}

/// Lien encodé dans le QR code.
struct PairingLink: Equatable, Sendable {
    let url: String

    /// nil si le Mac n'a pas d'adresse sur le réseau local.
    init?(mode: AddressMode, port: UInt16, token: String) {
        let host = switch mode {
        case .bonjour: NetworkInfo.bonjourHost
        case .ip: NetworkInfo.localIPv4
        }
        guard let host else { return nil }
        url = "http://\(host):\(port)/#t=\(token)"
    }
}
