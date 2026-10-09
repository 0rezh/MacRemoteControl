import Foundation

/// Constantes de l'app, regroupées par domaine.
enum Constants {

    enum Server {
        static let port: UInt16 = 8765
        static let socketRoute = "GET /ws"
        static let filesRoute = "GET *"
        /// Attente avant de refuser un mauvais jeton, pour décourager les essais à la chaîne.
        static let badTokenDelay: Duration = .seconds(1)
    }

    enum Pairing {
        static let tokenLength = 24
        /// Sans caractères ambigus (0/O, 1/l/I).
        static let tokenAlphabet = Array("abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789")
    }

    /// Clés UserDefaults (inchangées depuis la v1 : les téléphones restent jumelés).
    enum Defaults {
        static let token = "token"
        static let addressMode = "addressMode"
        static let keepsMacAwake = "keepAwake"
    }

    enum Accessibility {
        /// macOS ne notifie pas les changements de permission : on vérifie à cet intervalle.
        static let pollInterval: TimeInterval = 2
        static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
    }

    enum Web {
        static let bundleDirectory = "web"
        static let devDirectoryEnvironmentKey = "MAC_REMOTE_WEB_DIR"
        static let devRelativePath = "../web/out"
    }

    enum Mouse {
        /// Pendant ce délai après un déplacement, on repart de la dernière position envoyée.
        static let positionMemory: TimeInterval = 0.25
        /// Distance max (points) entre deux clics pour former un double-clic.
        static let doubleClickTolerance: CGFloat = 6
    }
}
