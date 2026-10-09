import FlyingFox
import Foundation

/// Ce que le serveur demande au reste de l'app : le modèle ne connaît pas les contrôleurs.
@MainActor
protocol RemoteServerDelegate: AnyObject, Sendable {
    func remoteServer(_ server: RemoteServer, shouldAcceptToken token: String) -> Bool
    func remoteServer(_ server: RemoteServer, didReceive action: RemoteAction) -> RemoteState
    func remoteServer(_ server: RemoteServer, didReceive event: PointerEvent)
    func remoteServer(_ server: RemoteServer, didReceive input: KeyboardInput)
    /// Un téléphone authentifié s'est déconnecté : rien ne doit rester enfoncé (clic, ⌘…).
    func remoteServerClientDidDisconnect(_ server: RemoteServer)
    func remoteServerCurrentState(_ server: RemoteServer) -> RemoteState
    func remoteServer(_ server: RemoteServer, didChangeClientCount count: Int)
}

/// Unique classe réseau de l'app : sert la PWA et reçoit les commandes des téléphones (HTTP + WebSocket).
final class RemoteServer: Sendable {
    weak let delegate: (any RemoteServerDelegate)?
    let hub = ClientHub()

    private let httpServer: HTTPServer
    private let webRoot: URL

    init(port: UInt16, webRoot: URL, delegate: any RemoteServerDelegate) {
        self.delegate = delegate
        self.webRoot = webRoot
        self.httpServer = HTTPServer(port: port, logger: .disabled)
    }

    func run() async throws {
        await httpServer.appendRoute(HTTPRoute(Constants.Server.socketRoute), to: .webSocket(RemoteSocketHandler(server: self)))
        await httpServer.appendRoute(HTTPRoute(Constants.Server.filesRoute), to: StaticFileHandler(root: webRoot))
        try await httpServer.run()
    }

    func waitUntilListening() async throws {
        try await httpServer.waitUntilListening()
    }

    func broadcast(_ state: RemoteState) async {
        await hub.broadcast(ServerMessage.state(state).json)
    }

    /// Utilisé quand le jeton est régénéré : les téléphones devront rescanner le QR code.
    func disconnectAll() async {
        await hub.disconnectAll(with: ServerMessage.tokenRevoked.json)
        await delegate?.remoteServer(self, didChangeClientCount: 0)
    }
}
