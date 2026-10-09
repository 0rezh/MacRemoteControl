import FlyingFox
import Foundation

/// Une connexion WebSocket = un téléphone. Décode ses messages et les transmet au délégué du serveur.
struct RemoteSocketHandler: WSMessageHandler {
    unowned let server: RemoteServer

    func makeMessages(for client: AsyncStream<WSMessage>) async throws -> AsyncStream<WSMessage> {
        let (output, continuation) = AsyncStream<WSMessage>.makeStream()
        let id = UUID()

        Task {
            var isAuthenticated = false
            for await message in client {
                guard case let .text(text) = message, let incoming = ClientMessage(json: text) else { continue }
                let delegate = server.delegate

                switch incoming.type {
                case "hello":
                    guard let token = incoming.token,
                          await delegate?.remoteServer(server, shouldAcceptToken: token) == true
                    else {
                        try? await Task.sleep(for: Constants.Server.badTokenDelay)
                        continuation.yield(.text(ServerMessage.badToken.json))
                        continuation.yield(.close(.policyViolation))
                        continuation.finish()
                        return
                    }
                    isAuthenticated = true
                    let count = await server.hub.add(id, continuation)
                    await delegate?.remoteServer(server, didChangeClientCount: count)
                    if let state = await delegate?.remoteServerCurrentState(server) {
                        continuation.yield(.text(ServerMessage.welcome(state).json))
                    }

                case "action":
                    guard isAuthenticated, let action = incoming.action,
                          let state = await delegate?.remoteServer(server, didReceive: action)
                    else { continue }
                    continuation.yield(.text(ServerMessage.state(state).json))

                case "ping":
                    continuation.yield(.text(ServerMessage.pong.json))

                default:
                    guard isAuthenticated else { continue }
                    if let input = incoming.keyboardInput {
                        await delegate?.remoteServer(server, didReceive: input)
                    } else if let event = incoming.pointerEvent {
                        await delegate?.remoteServer(server, didReceive: event)
                    }
                }
            }

            if isAuthenticated {
                await server.delegate?.remoteServerClientDidDisconnect(server)
            }
            if let count = await server.hub.remove(id) {
                await server.delegate?.remoteServer(server, didChangeClientCount: count)
            }
            continuation.finish()
        }

        return output
    }
}
